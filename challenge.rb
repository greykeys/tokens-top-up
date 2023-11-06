require 'optparse'
require 'json'
require "securerandom"

# A script / module to
# 1. Parse companies and user data
# 2. Batch top up users within companies
# 3. Generate report for changes made

############################
######## Entities ##########
############################

class Company
  attr_reader :id, :name, :top_up, :email_status

  def initialize(company_data)
    @id   = company_data['id']
    @name   = company_data['name']
    @top_up  = company_data['top_up']
    @email_status = company_data['email_status']
  end

  def is_valid?
    # company should have an id
    # top up amount should be a non-negative number
    return @id && \
      @top_up.is_a?(Numeric) && @top_up >= 0 
  end

end

class User
  attr_reader :uuid, :id, :first_name, :last_name, :company_id, :active_status, :email, :email_status, :tokens

  def initialize(user_data)
    @uuid = SecureRandom.hex(4) # to handle any dupe user ids in the provided data
    @id   = user_data['id']
    @first_name   = user_data['first_name']
    @last_name  = user_data['last_name']
    @company_id = user_data['company_id']
    @active_status = user_data['active_status']
    @email  = user_data['email']
    @email_status = user_data['email_status']
    @tokens = user_data['tokens']
  end

  def top_up(top_up_amount)
    @tokens = @tokens + top_up_amount
  end

  def is_active?
    return @active_status
  end

  def is_valid?
    # user should have a company id
    # user tokens should be a number
    return @company_id && \
      @tokens.is_a?(Numeric) 
  end
end


class UserTokenChange
  # represents a single change (user top up) made within the top up task 

  attr_reader :company_id, :user_uuid, :previous_tokens, :new_tokens, :email_sent

  def initialize(company_id, user_uuid, previous_tokens, new_tokens, email_sent)
    @company_id = company_id
    @user_uuid   = user_uuid
    @previous_tokens = previous_tokens
    @new_tokens = new_tokens
    @email_sent = email_sent
  end

end

#############################################
##### Top up (i.e. operational) methods #####
#############################################

def top_up_user(user, company)
  email_sent = false
  previous_tokens = user.tokens

  # handle top up and email
  user.top_up(company.top_up)
  if user.email_status && company.email_status
    # send_email(...)
    email_sent = true
  end

  return UserTokenChange.new(company.id, user.uuid, previous_tokens, user.tokens, email_sent)
end


def top_up_company(company, users)
  company_token_changes = []
  active_users = users.select(&:is_active?)
  for active_user in active_users do
    user_token_change = top_up_user(active_user, company)
    if user_token_change
      company_token_changes.push(user_token_change)
    end
  end
  return company_token_changes
end

def batch_top_up(companies, company_id_to_user_ids, user_uuid_to_user)
  all_token_changes = []
  for company in companies do
    company_users = company_id_to_user_ids[company.id].map { |user_id| user_uuid_to_user[user_id] }
    company_token_changes = top_up_company(company, company_users)
    all_token_changes.push(*company_token_changes)
  end
  return all_token_changes
end

#############################
##### Reporting methods #####
#############################

def get_token_difference(user_token_change)
  return user_token_change.new_tokens - user_token_change.previous_tokens
end

def get_user_report(user, previous_tokens, new_tokens)
  return [
    "\t\t#{user.last_name}, #{user.first_name}, #{user.email}",
    "\t\t  Previous Token Balance, #{previous_tokens}",
    "\t\t  New Token Balance #{new_tokens}"
  ]
end

def get_company_report(company, token_changes, user_uuid_to_user)
  company_report = []
  sorted_token_changes = token_changes.sort_by { |token_change| user_uuid_to_user[token_change.user_uuid].last_name }

  total_company_topup = 0
  changes_with_email, changes_without_email = sorted_token_changes.partition(&:email_sent)

  company_report.push([
    "\n\tCompany Id: #{company.id}",
    "\tCompany Name: #{company.name}"
  ])

  company_report.push("\tUsers Emailed:")
  changes_with_email.each do |token_change|
    emailed_user = user_uuid_to_user[token_change.user_uuid]
    company_report.push(*get_user_report(emailed_user, token_change.previous_tokens, token_change.new_tokens))
    total_company_topup += get_token_difference(token_change)
  end
  
  company_report.push("\tUsers Not Emailed:")
  changes_without_email.each do |token_change|
    not_emailed_user = user_uuid_to_user[token_change.user_uuid]
    company_report.push(*get_user_report(not_emailed_user, token_change.previous_tokens, token_change.new_tokens))
    total_company_topup += get_token_difference(token_change)
  end
  
  company_report.push("\t\tTotal amount of top ups for #{company.name}: #{total_company_topup}")

  return company_report
end

def generate_report( token_changes, company_id_to_company, user_uuid_to_user, output_file)
  token_changes_by_company_id = token_changes.group_by { |token_change| token_change.company_id }
  sorted_company_ids = token_changes_by_company_id.keys().sort()
  full_report = []
  for company_id in sorted_company_ids do
    company = company_id_to_company[company_id]
    company_token_changes = token_changes_by_company_id[company_id]
    if company_token_changes
      full_report.push(*get_company_report(company, company_token_changes, user_uuid_to_user))
    end
  end

  File.open(output_file, "w") do |out|
    full_report.each { |item| out.puts(item) }
    out.puts() # adding a blank line to match expected output
  end
end

#############################
##### Utility methods #######
#############################

def read_json_file(file_path)
  File.read(file_path)
end

def parse_json_data(json_data)
  JSON.parse(json_data)
end

def create_objects(data, object_class)
  data.map { |item| object_class.new(item) }
end

def get_company_id_to_user_uuids_mapping(users)
  users.each_with_object(Hash.new { |h, k| h[k] = [] }) do |user, hash|
    hash[user.company_id] << user.uuid
  end
end


def get_companies(companies_data_file)
  companies_json = parse_json_data(read_json_file(companies_data_file))
  companies = create_objects(companies_json, Company)

  # eliminate any companies which have the same company id
  # as these may cause erroneous top ups for the same user
  company_id_to_companies = companies.group_by { |company| company.id }
  non_dupe_companies = []
  company_id_to_companies.each do |company_id, companies_with_same_company_id|
    if companies_with_same_company_id.length == 1
      # i.e. there is only one company with this id, so we can continue to process it
      non_dupe_companies.push(*companies_with_same_company_id)
    else
      puts "Found multiple companies (#{companies_with_same_company_id.length}) with the same id: #{company_id}. Skipping these companies."
    end
  end
  valid_companies =  non_dupe_companies.select(&:is_valid?)
  return valid_companies
end


def get_users(users_data_file)
  users_json = parse_json_data(read_json_file(users_data_file))
  users = create_objects(users_json, User)
  return users.select(&:is_valid?)
end

#############################
####### Task methods ########
#############################

def top_up_and_report(companies_data_file, users_data_file, output_file)
  # parse / fetch data
  companies = get_companies(companies_data_file)
  users = get_users(users_data_file)

  # build data structures for efficient processing
  company_id_to_company = companies.map { |company| [company.id, company] }.to_h
  user_uuid_to_user = users.map { |user| [user.uuid, user] }.to_h
  company_id_to_user_uuids = get_company_id_to_user_uuids_mapping(users)

  # top up operations
  token_changes = batch_top_up(companies, company_id_to_user_uuids, user_uuid_to_user)

  # generate report based on changes made
  generate_report(token_changes, company_id_to_company, user_uuid_to_user, output_file)
end

#############################
####### Execution ###########
#############################

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: challenge.rb [options]"

  opts.on("--companies-file PATH_TO_COMPANIES_FILE", "--cf PATH_TO_COMPANIES_FILE", "Path to companies file") do |cf|
    options[:companies_file] = cf
  end

  opts.on("--users-file PATH_TO_USERS_FILE", "--uf PATH_TO_USERS_FILE", "Path to users file") do |uf|
    options[:users_file] = uf
  end

  opts.on("--output-file PATH_TO_OUTPUT_FILE", "--of PATH_TO_OUTPUT_FILE", "Path to output file") do |of|
    options[:output_file] = of
  end

  opts.on('-h', '--help', 'Prints this help message') do
    puts opts
    exit
  end
end

option_parser.parse!

top_up_and_report(
  options[:companies_file] || './companies.json',
  options[:users_file] || './users.json',
  options[:output_file] || './output.txt'
)