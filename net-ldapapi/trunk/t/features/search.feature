Feature: Searching the directory
 As a directory consumer
 I want to ensure that I can search the directory
 In order to find relevant entries

 Background:
   Given a usable Net::LDAPapi class

 Scenario: Can find objects that exist within the directory
   Given a Net::LDAPapi object that has been connected to the LDAP server
   When I've bound with default authentication to the directory
   And I've searched for records with scope LDAP_SCOPE_SUBTREE
   Then the search result is LDAP_SUCCESS
   And the search count matches
   And for each entry returned the dn and the first attribute are valid

 Scenario: Can asynchronously find objects that exist within the directory
   Given a Net::LDAPapi object that has been connected to the LDAP server
   When I've asynchronously bound with default authentication to the directory
   And I've asynchronously searched for records with scope LDAP_SCOPE_SUBTREE
   Then after waiting for all results, the search result message type is LDAP_RES_SEARCH_RESULT 
   And the search result is LDAP_SUCCESS
   And the search count matches
   And for each entry returned the dn and the first attribute are valid
