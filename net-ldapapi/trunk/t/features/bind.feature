Feature: Binding to the directory
 As a directory consumer
 I want to ensure that I can bind properly to directories
 In order to establish my identity

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
