our %TestConfig = (
  'ldap' => {
    'server' => 'localhost',
    'port' => '389',
    'base_dn' => 'dc=example,dc=com',
    'default_bind_type' => 'simple',
    'bind_types' => {
      'anonymous' => {
        'enabled' => 1,
      },
      'simple' => {
        'enabled' => 1,
        'bind_dn' => 'cn=admin,dc=example,dc=com',
        'bind_pw' => 'password',
      }
    }
  },
  'search' => {
     'filter' => "sn=Last",
     'count' => 1,
  },
  'data' => {
    'test_container_attributes' => {
      'objectClass' => ['top', 'organizationalUnit'],
      'ou' => 'Test Container',
    },
    'container_attributes' => {
      'objectClass' => ['top', 'organizationalUnit'],
      'ou' => 'Test - Add Container',
    },
    'entry_attributes' => {
      'objectClass' => ['top', 'person' ,'organizationalPerson', 'inetOrgPerson'],
      'cn' => 'Test - Add Entry',
      'sn' => 'Entry',
      'givenName' => 'Test - Add',
    },
    'test_container_dn' => 'ou=Test',
    'container_dn' => 'ou=Test - Add Container',
    'entry_dn' => 'cn=Test - Add Entry',
  },
  'rename' => {
    'old_dn' => 'cn=Test - Add Entry',
    'new_dn' => 'cn=Test - Add Entry,ou=Test - Add Container'
  }
);

if ( -e $ENV{'HOME'} . '/.net-ldapapi-test-config.conf') {
  require $ENV{'HOME'} . '/.net-ldapapi-test-config.conf';
}

1;
