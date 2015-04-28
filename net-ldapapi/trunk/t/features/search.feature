Feature: Searching the directory
 As a directory consumer
 I want to ensure that I can search the directory
 In order to find relevant entries

 Background:
   Given a usable Net::LDAPapi class

 Scenario: Can search
   Given a Net::LDAPapi object that has been connected to the LDAP server
   When I've bound with default authentication to the directory
   And I've searched for records with scope LDAP_SCOPE_SUBTREE
   Then the search result is LDAP_SUCCESS
   And the search count matches
