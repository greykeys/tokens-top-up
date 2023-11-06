# Tokens Top Up

## Description

```
  You have a json file of users.
  You have a json file of companies.

  Please look at these files.
  Create code in Ruby that process these files and creates an
  output.txt file.

  Criteria for the output file.
  Any user that belongs to a company in the companies file and is active
  needs to get a token top up of the specified amount in the companies top up
  field.

  If the users company email status is true indicate in the output that the
  user was sent an email ( don't actually send any emails).
  However, if the user has an email status of false, don't send the email
  regardless of the company's email status.

  Companies should be ordered by company id.
  Users should be ordered alphabetically by last name.

  Important points
  - There could be bad data
  - The code should be runnable in a command line
  - Code needs to be written in Ruby
  - Code needs to be cloneable from github
  - Code file should be named challenge.rb

  An example_output.txt file is included.
  Use the example file provided to see what the output should look like.

  Assessment Criteria
  - Functionality
  - Error Handling
  - Reusability
  - Style
  - Adherence to convention
  - Documentation
  - Communication
```

### Executing the program

#### Default inputs and outputs

```
ruby challenge.rb
```

#### Custom inputs and outputs

```
ruby --companies-file <path-to-your-custom-companies-data-file> --users-file <path-to-your-custom-users-data-file> --output-file <path-to-your-custom-output-file>
```

or

```
ruby --cf <path-to-your-custom-companies-data-file> --uf <path-to-your-custom-users-data-file> --of <path-to-your-custom-output-file>
```

for example

```
ruby challenge.rb --cf tests/003_invalid_token_values/companies.json --uf tests/003_invalid_token_values/users.json --of tests/003_invalid_token_values/output.txt
```

#### Help

```
ruby challenge.rb --help
```

### Assumptions and validations

- We assume users may have duplicate IDs (as in the default example provided), so we generate our own unique UUIDs for the users to enable processing for all possible users.

- We assume that companies are expected to have unique IDs, but in case we do encounter companies with duplicate IDs in the provided data, we will log these cases and skip processing these companies to avoid any cases of double/erroneous top ups for users.

- In case of any non-numeric token or top up values, we will not process the associated company or users.

- A company without an ID is not processed.

- A user without an associated company ID is not processed.

- In general, the goal is to do the best-effort operations. In case of bad or invalid data, we will try to skip the least amount of processing as necessary and continue with the rest.

### Potential future enhancements

- More logging when skipping over invalid companies or users.

- Adding more test cases.

- Type hinting.
