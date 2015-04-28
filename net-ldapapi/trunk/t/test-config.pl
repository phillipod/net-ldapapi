our %TestConfig = (
  'LDAP' => {
    'Server' => 'localhost',
    'Port' => '389',
    'BaseDN' => 'dc=example,dc=com',
    'DefaultBindType' => 'Simple',
    'BindTypes' => {
      'Anonymous' => {
        'Enabled' => 1,
      },
      'Simple' => {
        'Enabled' => 1,
        'BindDN' => 'cn=admin,dc=example,dc=com',
        'BindPW' => 'password'
      }
    }
  },
  'Search' => {
     'Filter' => "sn=Last Name",
     "Count" => 1,
  }
);

if ( -e $ENV{'HOME'} . "/.net-ldapapi-test-config.conf") {
  require $ENV{'HOME'} . "/.net-ldapapi-test-config.conf";
}

1;
