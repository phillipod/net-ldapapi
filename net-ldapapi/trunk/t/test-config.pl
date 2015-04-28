our %TestConfig = (
  'ldap' => {
    'server' => 'localhost',
    'port' => '389',
    'base_dn' => 'dc=example,dc=com',
    'default_bind_type' => 'simple',
    'bind_types' => {
      'anonymous' => {
        'enabled' => 0,
      },
      'simple' => {
        'enabled' => 1,
        'bind_dn' => 'cn=admin,dc=example,dc=com',
        'bind_pw' => 'password',
      }
    }
  },
  'search' => {
     'filter' => "sn=Last Name",
     "count" => 1,
  }
);

if ( -e $ENV{'HOME'} . "/.net-ldapapi-test-config.conf") {
  require $ENV{'HOME'} . "/.net-ldapapi-test-config.conf";
}

1;
