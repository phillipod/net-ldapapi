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
    'test_container_dn' => 'ou=Test Container',
    'container_dn' => 'ou=Test - Add Container',
    'entry_dn' => 'cn=Test - Add Entry',
  },
  'rename' => {
    'dn' => 'cn=Test - Add Entry',
    'new_rdn' => 'cn=Test - Add Entry',
    'new_super' => 'ou=Test - Add Container'
  },
  'modify' => {
    'new_attribute' => {
      'title' => { 'a' => ['New Test Title'] }
    },
    'modify_attribute' => {
      'title' => { 'r' => ['Modified Test Title'] }
    },
    'remove_attribute' => {
      'title' => ''
    },
  },
  'syncrepl' => {
    'enabled' => 1,
    'cookie_dir' => '/tmp/'  
  },
  'server_controls' => {
    'sss' => [
      {
        'attributeType' => 'sn', 
        'orderingRule' => '2.5.13.3', 
        'reverseOrder' => 1
      },
    ],
  },
);

if ( -e $ENV{'HOME'} . '/.net-ldapapi-test-config.conf') {
  require $ENV{'HOME'} . '/.net-ldapapi-test-config.conf';
}

1;
