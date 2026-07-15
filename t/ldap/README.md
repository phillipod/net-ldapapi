# Minimal OpenLDAP fixture

The Cucumber suite does not require a project-specific LDAP schema. Its entry
definitions use only the standard `core`, `cosine`, and `inetorgperson` schema
files shipped with OpenLDAP. In load order, the complete minimum is:

1. `core.schema`
2. `cosine.schema`
3. `inetorgperson.schema`

Together they provide every object class and user attribute named by
`t/test-config.pl`:

- `top`, `organizationalUnit`, `person`, `organizationalPerson`, and
  `inetOrgPerson`
- `objectClass`, `ou`, `cn`, `sn`, `givenName`, and `title`

Do not add local definitions for these names or copy reduced versions of their
standard definitions. Doing so would either duplicate schema already shipped by
OpenLDAP or create an incompatible version of `inetOrgPerson`.

## Bootstrap data

[`bootstrap.ldif`](bootstrap.ldif) is the smallest persistent directory tree
that satisfies the default test configuration:

- `dc=example,dc=com` exists as the search base and parent for write tests.
- `cn=admin,dc=example,dc=com` is the configured database root DN.
- The same admin entry is the one and only persistent `(sn=Last)` result, so
  search, Server Side Sort, and Virtual List View tests all see the configured
  count of one.

The suite creates `ou=Test Container,dc=example,dc=com` and all of its mutable
children itself. Each scenario removes that subtree, so it must not appear in
the bootstrap LDIF.

## Server capabilities

Schema and data alone are not enough for every scenario. The server must also:

- listen on both `ldap://` and `ldapi:///`;
- accept the configured simple root bind and anonymous binds;
- support SASL EXTERNAL over LDAPI with the peer-credential identity;
- load the `syncprov` overlay for persistent RFC 4533 Sync searches;
- load the `sssvlv` overlay for Server Side Sort and Virtual List View; and
- expose the Who Am I and Cancel extended operations.

[`slapd.conf`](slapd.conf) captures the schema, database, root credential, and
overlay portion of that contract for the Debian/Ubuntu OpenLDAP layout. Other
distributions may use different schema and module directories.

## Loading and checking the fixture

From the repository root, with `slapd`, its overlays, and the LDAP command-line
tools installed:

```sh
rm -rf /tmp/net-ldapapi-slapd-data
install -d /tmp/net-ldapapi-slapd-data
slaptest -f t/ldap/slapd.conf -u
slapadd -f t/ldap/slapd.conf -l t/ldap/bootstrap.ldif
slapd -f t/ldap/slapd.conf -h 'ldap:/// ldapi:///'
```

`slapd` needs permission to bind the configured TCP port (389). Run the final
command with suitable privileges, or override the TCP server details in
`~/.net-ldapapi-test-config.conf` when using an unprivileged port.

Before enabling the developer suite, verify its persistent search invariant:

```sh
ldapsearch -LLL -x -H ldap://localhost \
  -D 'cn=admin,dc=example,dc=com' -w password \
  -b 'dc=example,dc=com' '(sn=Last)' cn
```

The query must return exactly one entry. Then set `$RunDeveloperTests = 1` in
`~/.net-ldapapi-test-config.conf` and run:

```sh
prove -lv t/01-bdd-cucumber.t
```
