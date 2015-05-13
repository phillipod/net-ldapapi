Feature: Using server controls to control results
 As a directory consumer
 I want to ensure that I can use server controls when querying the directory
 In order to be able to utilise the extended features of my directory

 Background:
   Given a usable Net::LDAPapi class

 Scenario: Can use the Server Side Sort control
   Given a Net::LDAPapi object that has been connected to the LDAP server
   And the server side sort control definition
   When I've bound with default authentication to the directory
   And I've created a server side sort control
   And I've searched for records with scope LDAP_SCOPE_SUBTREE, with server control server side sort
   Then the search result is LDAP_SUCCESS
   And the search count matches
   And using next_entry for each entry returned the dn and all attributes using next_attribute are valid
   And the server side sort control was successfully used
