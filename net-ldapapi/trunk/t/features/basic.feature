Feature: Basic tests of Net::LDAPapi
 As a developer planning to use Net::LDAPapi
 I want to test the core functionality of Net::LDAPapi
 In order to have confidence in it

 Background:
   Given a usable Net::LDAPapi class

 Scenario: Can bind anonymously
   Given a Net::LDAPapi object that has been connected to the LDAP server
   When I've bound with anonymous authentication to the directory
   Then the bind result is LDAP_SUCCESS

 Scenario: Can bind with simple authentication
   Given a Net::LDAPapi object that has been connected to the LDAP server
   When I've bound with simple authentication to the directory
   Then the bind result is LDAP_SUCCESS

 Scenario: Can search
   Given a Net::LDAPapi object that has been connected to the LDAP server
   When I've bound with default authentication to the directory
   And I've searched for records with scope LDAP_SCOPE_SUBTREE
   Then the bind result is LDAP_SUCCESS
   Then the search result is LDAP_SUCCESS
   Then the search count matches
