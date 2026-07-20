# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..13\n"; }
END {print "modinit  - not ok\n" unless $loaded;}
use Net::LDAPapi;
$loaded = 1;
print "modinit  - ok\n";

##
## BER printf/scanf round trip
##

$ber = ber_alloc_t(LBER_USE_DER);
if ($ber && ber_printf($ber, '{eb}', 3, 1) >= 0)
{
   print "berprintf - ok\n";
} else {
   print "berprintf - not ok\n";
   exit -1;
}

$encoded = ber_flatten($ber);
ber_free($ber, 1);
$ber = ber_init($encoded);
($enum, $boolean) = ber_scanf($ber, '{eb}');
ber_free($ber, 1);

if ($enum == 3 && $boolean)
{
   print "berscanf  - ok\n";
} else {
   print "berscanf  - not ok\n";
   exit -1;
}

$ber = ber_alloc_t(LBER_USE_DER);
$oversized_bit_count_rejected = !eval {
   ber_printf($ber, 'B', 'A', 24);
   1;
};
ber_free($ber, 1);

if ($oversized_bit_count_rejected && $@ =~ /bit length exceeds the supplied buffer/)
{
   print "berbits   - ok\n";
} else {
   print "berbits   - not ok\n";
   exit -1;
}

######################### End of black magic.

##
## Change these values for test to work...
##

print "\nEnter LDAP Server: ";
chomp($ldap_host = <>);
print "Enter port: ";
chomp($ldap_port = <>);
print "Enter Search Filter (ex. uid=abc123): ";
chomp($filter = <>);
print "Enter LDAP Search Base (ex. o=Org, c=US): ";
chomp($BASEDN = <>);
print "\n";

if (!$ldap_host)
{
   die "Please edit \$BASEDN, \$filter and \$ldap_host in test.pl.\n";
}

##
##  Initialize LDAP Connection
##

if (($ld = new Net::LDAPapi(-host=>$ldap_host,-port=>$ldap_port)) == -1)
{
   print "open     - not ok\n";
   exit -1; 
}
print "open     - ok\n";

##
##  Bind as DN, PASSWORD (NULL,NULL) on LDAP connection $ld
##

if ($ld->bind_s != LDAP_SUCCESS)
{
   $ld->perror("bind_s");
   print "bind     - not ok\n";
   exit -1;
}
print "bind     - ok\n";

##
## ldap_whoami_s
##

$id = '';

if ($ld->whoami_s(\$id) != LDAP_SUCCESS)
{
   $ld->perror("whoami_s");
   print "whoami   - not ok\n";
   exit -1;
}
print "whoami   - ok\n";

##
## ldap_extended_operation_s
##

%result = ();

if ($ld->extended_operation_s(-oid => "1.3.6.1.4.1.4203.1.11.3", -result => \%result) != LDAP_SUCCESS)
{
   $ld->perror("ldap_extended_operation_s");
   print "ldap_extended_operation   - not ok\n";
   exit -1;
}
print "ldap_extended_operation    - ok\n";


##
## ldap_search_s - Synchronous Search
##

@attrs = ();

if ($ld->search_s($BASEDN,LDAP_SCOPE_SUBTREE,$filter,\@attrs,0) != LDAP_SUCCESS)
{
   $ld->perror("search_s");
   print  "search   - not ok\n";
}
print "search   - ok\n";

##
## ldap_count_entries - Count Matched Entries
##

if ($ld->count_entries == -1)
{
   ldap_perror($ld,"count_entry");
   print "count    - not ok\n";
}
print "count    - ok\n";

##
## first_entry - Get First Matched Entry
## next_entry  - Get Next Matched Entry
##

   for ($ent = $ld->first_entry; $ent; $ent = $ld->next_entry)
   {
      
##
## ldap_get_dn  -  Get DN for Matched Entries
##

      if ($ld->get_dn ne "")
      {
         print "getdn    - ok\n";
      } else {
         $ld->perror("get_dn");
         print "getdn    - not ok\n";
      }

      if (($attr = $ld->first_attribute) ne "")
      {
         print "firstatt - ok\n";

##
## ldap_get_values
##

         @vals = $ld->get_values($attr);
         if ($#vals >= 0)
         {
            print "getvals  - ok\n";
         } else {
            print "getvals  - not ok\n";
         }
      } else {
         print "firstattr - not ok\n";
      }


   }


##
##  Unbind LDAP Connection
##

$ld->unbind();
