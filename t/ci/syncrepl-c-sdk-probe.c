/*
 * Exercise the notification and cancellation sequences from
 * t/features/syncrepl.feature and t/features/syncrepl_cancel.feature using
 * the OpenLDAP C client SDK directly.  In particular, keep the listener
 * asynchronous and issue the mutations immediately after ldap_search_ext().
 *
 * Usage:
 *   syncrepl-c-sdk-probe LDAP_URI BIND_DN PASSWORD BASE_DN [TIMEOUT_SECONDS] [notification|cancel]
 */

#include <ldap.h>
#include <lber.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

#define SYNCPROBE_DN_SIZE 1024
#define SYNCPROBE_NAME_SIZE 256

static void
report_ldap_error(const char *operation, int rc)
{
	fprintf(stderr, "C-SYNCPROBE %s: %d (%s)\n", operation, rc,
		ldap_err2string(rc));
}

static void
report_stage(const char *stage)
{
	fprintf(stderr, "NET_LDAPAPI_C_SYNC_STAGE\t%s\n", stage);
}

static int
add_organizational_unit(LDAP *ld, const char *dn, const char *ou)
{
	char *object_classes[] = { "top", "organizationalUnit", NULL };
	char *ou_values[] = { (char *)ou, NULL };
	LDAPMod object_class_mod;
	LDAPMod ou_mod;
	LDAPMod *mods[] = { &object_class_mod, &ou_mod, NULL };
	int rc;

	memset(&object_class_mod, 0, sizeof(object_class_mod));
	object_class_mod.mod_op = LDAP_MOD_ADD;
	object_class_mod.mod_type = "objectClass";
	object_class_mod.mod_values = object_classes;

	memset(&ou_mod, 0, sizeof(ou_mod));
	ou_mod.mod_op = LDAP_MOD_ADD;
	ou_mod.mod_type = "ou";
	ou_mod.mod_values = ou_values;

	rc = ldap_add_ext_s(ld, dn, mods, NULL, NULL);
	if (rc != LDAP_SUCCESS) {
		report_ldap_error("ldap_add_ext_s(organizationalUnit)", rc);
	}
	return rc;
}

static int
add_person(LDAP *ld, const char *dn, const char *cn)
{
	char *object_classes[] = {
		"top", "person", "organizationalPerson", "inetOrgPerson", NULL
	};
	char *cn_values[] = { (char *)cn, NULL };
	char *sn_values[] = { "C SDK SyncRepl Notification Probe", NULL };
	char *given_name_values[] = { "C SDK", NULL };
	LDAPMod object_class_mod;
	LDAPMod cn_mod;
	LDAPMod sn_mod;
	LDAPMod given_name_mod;
	LDAPMod *mods[] = {
		&object_class_mod, &cn_mod, &sn_mod, &given_name_mod, NULL
	};
	int rc;

	memset(&object_class_mod, 0, sizeof(object_class_mod));
	object_class_mod.mod_op = LDAP_MOD_ADD;
	object_class_mod.mod_type = "objectClass";
	object_class_mod.mod_values = object_classes;

	memset(&cn_mod, 0, sizeof(cn_mod));
	cn_mod.mod_op = LDAP_MOD_ADD;
	cn_mod.mod_type = "cn";
	cn_mod.mod_values = cn_values;

	memset(&sn_mod, 0, sizeof(sn_mod));
	sn_mod.mod_op = LDAP_MOD_ADD;
	sn_mod.mod_type = "sn";
	sn_mod.mod_values = sn_values;

	memset(&given_name_mod, 0, sizeof(given_name_mod));
	given_name_mod.mod_op = LDAP_MOD_ADD;
	given_name_mod.mod_type = "givenName";
	given_name_mod.mod_values = given_name_values;

	rc = ldap_add_ext_s(ld, dn, mods, NULL, NULL);
	if (rc != LDAP_SUCCESS) {
		report_ldap_error("ldap_add_ext_s(person)", rc);
	}
	return rc;
}

static int
delete_entry(LDAP *ld, const char *dn)
{
	int rc = ldap_delete_ext_s(ld, dn, NULL, NULL);

	if (rc != LDAP_SUCCESS && rc != LDAP_NO_SUCH_OBJECT) {
		report_ldap_error("ldap_delete_ext_s", rc);
	}
	return rc;
}

static void
log_sync_state_control(LDAPControl *control)
{
	BerElement *ber;
	ber_int_t state = -1;
	struct berval entry_uuid = { 0 };

	ber = ber_init((struct berval *)&control->ldctl_value);
	if (ber == NULL) {
		fprintf(stderr, "C-SYNCPROBE Sync State control could not be decoded\n");
		return;
	}

	if (ber_scanf(ber, "{em", &state, &entry_uuid) == LBER_ERROR) {
		fprintf(stderr,
			"C-SYNCPROBE Sync State control decode failed (value length %lu)\n",
			(unsigned long)control->ldctl_value.bv_len);
	} else {
		fprintf(stderr,
			"C-SYNCPROBE Sync State control state=%ld entryUUID-length=%lu\n",
			(long)state, (unsigned long)entry_uuid.bv_len);
	}

	ber_free(ber, 1);
}

static void
log_entry_controls(LDAP *ld, LDAPMessage *message)
{
	LDAPControl **controls = NULL;
	int rc;
	int index;

	rc = ldap_get_entry_controls(ld, message, &controls);
	if (rc != LDAP_SUCCESS) {
		report_ldap_error("ldap_get_entry_controls", rc);
		return;
	}

	if (controls == NULL) {
		fprintf(stderr, "C-SYNCPROBE entry has no response controls\n");
		return;
	}

	for (index = 0; controls[index] != NULL; index++) {
		LDAPControl *control = controls[index];

		fprintf(stderr, "C-SYNCPROBE entry control %s (value length %lu)\n",
			control->ldctl_oid,
			(unsigned long)control->ldctl_value.bv_len);
		if (strcmp(control->ldctl_oid, LDAP_CONTROL_SYNC_STATE) == 0) {
			log_sync_state_control(control);
		}
	}

	ldap_controls_free(controls);
}

static int
wait_for_notification(LDAP *ld, int message_id, const char *expected_entry_dn,
	const char *expected_container_dn, int timeout_seconds)
{
	time_t deadline = time(NULL) + timeout_seconds;

	while (time(NULL) <= deadline) {
		struct timeval timeout;
		LDAPMessage *message = NULL;
		int rc;
		int message_type;

		timeout.tv_sec = 1;
		timeout.tv_usec = 0;
		rc = ldap_result(ld, message_id, LDAP_MSG_ONE, &timeout, &message);
		if (rc == 0) {
			continue;
		}
		if (rc == -1) {
			int error_number = LDAP_OTHER;

			(void)ldap_get_option(ld, LDAP_OPT_ERROR_NUMBER, &error_number);
			fprintf(stderr, "C-SYNCPROBE ldap_result failed: %s\n",
				ldap_err2string(error_number));
			return -1;
		}

		message_type = ldap_msgtype(message);
		fprintf(stderr, "C-SYNCPROBE ldap_result message type %d\n",
			message_type);

		if (message_type == LDAP_RES_SEARCH_ENTRY) {
			char *dn = ldap_get_dn(ld, message);

			if (dn == NULL) {
				fprintf(stderr, "C-SYNCPROBE ldap_get_dn failed\n");
				ldap_msgfree(message);
				return -1;
			}

			fprintf(stderr, "C-SYNCPROBE sync entry %s\n", dn);
			log_entry_controls(ld, message);
			if (strcasecmp(dn, expected_entry_dn) == 0 ||
				strcasecmp(dn, expected_container_dn) == 0) {
				ldap_memfree(dn);
				ldap_msgfree(message);
				return 0;
			}
			ldap_memfree(dn);
		} else if (message_type == LDAP_RES_SEARCH_RESULT) {
			char *matched_dn = NULL;
			char *error_message = NULL;
			LDAPControl **controls = NULL;
			int result_code = LDAP_OTHER;

			rc = ldap_parse_result(ld, message, &result_code, &matched_dn,
				&error_message, NULL, &controls, 0);
			if (rc == LDAP_SUCCESS) {
				fprintf(stderr,
					"C-SYNCPROBE terminal Sync search result: %d (%s)%s%s\n",
					result_code, ldap_err2string(result_code),
					error_message == NULL ? "" : ": ",
					error_message == NULL ? "" : error_message);
			} else {
				report_ldap_error("ldap_parse_result", rc);
			}
			if (matched_dn != NULL) {
				ldap_memfree(matched_dn);
			}
			if (error_message != NULL) {
				ldap_memfree(error_message);
			}
			if (controls != NULL) {
				ldap_controls_free(controls);
			}
			ldap_msgfree(message);
			return -1;
		} else if (message_type == LDAP_RES_INTERMEDIATE) {
			fprintf(stderr, "C-SYNCPROBE received Sync intermediate response\n");
		}

		ldap_msgfree(message);
	}

	fprintf(stderr,
		"C-SYNCPROBE timed out after %d seconds without an expected Sync entry\n",
		timeout_seconds);
	return -1;
}

static int
parse_timeout(const char *value, int *timeout_seconds)
{
	char *end = NULL;
	long parsed = strtol(value, &end, 10);

	if (value[0] == '\0' || end == NULL || *end != '\0' || parsed <= 0 ||
		parsed > 3600) {
		return -1;
	}

	*timeout_seconds = (int)parsed;
	return 0;
}

int
main(int argc, char **argv)
{
	const char *uri;
	const char *bind_dn;
	const char *password;
	const char *base_dn;
	int timeout_seconds = 30;
	int cancel_sync_search = 0;
	LDAP *ld = NULL;
	int protocol_version = LDAP_VERSION3;
	struct berval credential;
	struct berval *server_credential = NULL;
	char container_name[SYNCPROBE_NAME_SIZE];
	char entry_name[SYNCPROBE_NAME_SIZE];
	char child_name[SYNCPROBE_NAME_SIZE];
	char container_dn[SYNCPROBE_DN_SIZE];
	char entry_dn[SYNCPROBE_DN_SIZE];
	char child_dn[SYNCPROBE_DN_SIZE];
	/* Match listen_for_changes(): an empty Perl attribute array becomes { NULL }. */
	char *attributes[] = { NULL };
	LDAPControl sync_control;
	LDAPControl *server_controls[] = { &sync_control, NULL };
	BerElement *sync_ber = NULL;
	int search_message_id = -1;
	int probe_status = EXIT_FAILURE;
	int rc;

	if (argc < 5 || argc > 7) {
		fprintf(stderr,
			"Usage: %s LDAP_URI BIND_DN PASSWORD BASE_DN [TIMEOUT_SECONDS] [notification|cancel]\n",
			argv[0]);
		return EXIT_FAILURE;
	}

	uri = argv[1];
	bind_dn = argv[2];
	password = argv[3];
	base_dn = argv[4];
	if (argc >= 6 && parse_timeout(argv[5], &timeout_seconds) != 0) {
		fprintf(stderr, "C-SYNCPROBE invalid timeout: %s\n", argv[5]);
		return EXIT_FAILURE;
	}
	if (argc == 7) {
		if (strcmp(argv[6], "notification") == 0) {
			cancel_sync_search = 0;
		} else if (strcmp(argv[6], "cancel") == 0) {
			cancel_sync_search = 1;
		} else {
			fprintf(stderr, "C-SYNCPROBE invalid mode: %s\n", argv[6]);
			return EXIT_FAILURE;
		}
	}

	if (snprintf(container_name, sizeof(container_name),
		"Net LDAPapi C Sync %ld", (long)getpid()) >=
			(int)sizeof(container_name) ||
		snprintf(entry_name, sizeof(entry_name),
		"Net LDAPapi C Sync Entry %ld", (long)getpid()) >=
			(int)sizeof(entry_name) ||
		snprintf(child_name, sizeof(child_name),
		"Net LDAPapi C Sync Child %ld", (long)getpid()) >=
			(int)sizeof(child_name)) {
		fprintf(stderr, "C-SYNCPROBE could not construct test names\n");
		return EXIT_FAILURE;
	}

	if (snprintf(container_dn, sizeof(container_dn), "ou=%s,%s", container_name,
		base_dn) >= (int)sizeof(container_dn) ||
		snprintf(entry_dn, sizeof(entry_dn), "cn=%s,%s", entry_name,
		container_dn) >= (int)sizeof(entry_dn) ||
		snprintf(child_dn, sizeof(child_dn), "ou=%s,%s", child_name,
		container_dn) >= (int)sizeof(child_dn)) {
		fprintf(stderr, "C-SYNCPROBE could not construct test DNs\n");
		return EXIT_FAILURE;
	}

	report_stage("ldap_initialize");
	rc = ldap_initialize(&ld, uri);
	if (rc != LDAP_SUCCESS) {
		report_ldap_error("ldap_initialize", rc);
		goto cleanup;
	}

	report_stage("ldap_set_option_protocol_version");
	rc = ldap_set_option(ld, LDAP_OPT_PROTOCOL_VERSION, &protocol_version);
	if (rc != LDAP_SUCCESS) {
		report_ldap_error("ldap_set_option(LDAP_OPT_PROTOCOL_VERSION)", rc);
		goto cleanup;
	}

	credential.bv_val = (char *)password;
	credential.bv_len = strlen(password);
	report_stage("ldap_sasl_bind_s");
	rc = ldap_sasl_bind_s(ld, bind_dn, LDAP_SASL_SIMPLE, &credential, NULL,
		NULL, &server_credential);
	if (server_credential != NULL) {
		ber_bvfree(server_credential);
		server_credential = NULL;
	}
	if (rc != LDAP_SUCCESS) {
		report_ldap_error("ldap_sasl_bind_s", rc);
		goto cleanup;
	}

	fprintf(stderr, "C-SYNCPROBE creating %s\n", container_dn);
	report_stage("ldap_add_ext_s_test_container");
	if (add_organizational_unit(ld, container_dn, container_name) != LDAP_SUCCESS) {
		goto cleanup;
	}

	memset(&sync_control, 0, sizeof(sync_control));
	report_stage("encode_sync_request_control");
	sync_ber = ber_alloc_t(LBER_USE_DER);
	if (sync_ber == NULL ||
		ber_printf(sync_ber, "{eb}", LDAP_SYNC_REFRESH_AND_PERSIST, 1) < 0 ||
		ber_flatten2(sync_ber, &sync_control.ldctl_value, 0) < 0) {
		fprintf(stderr, "C-SYNCPROBE could not encode the Sync Request control\n");
		goto cleanup;
	}
	sync_control.ldctl_oid = (char *)LDAP_CONTROL_SYNC;
	sync_control.ldctl_iscritical = 1;

	report_stage("ldap_search_ext_sync_request");
	/* An omitted Perl -TIMEOUT is correctly represented by NULL in the C SDK. */
	rc = ldap_search_ext(ld, container_dn, LDAP_SCOPE_SUBTREE,
		"(objectClass=*)", attributes, 0, server_controls, NULL, NULL, 0,
		&search_message_id);
	if (rc != LDAP_SUCCESS) {
		report_ldap_error("ldap_search_ext(Sync Request)", rc);
		goto cleanup;
	}
	fprintf(stderr, "C-SYNCPROBE started Sync search message id %d\n",
		search_message_id);

	/* Keep the Gherkin ordering: do not drain the initial Sync refresh here. */
	report_stage("ldap_add_ext_s_entry");
	if (add_person(ld, entry_dn, entry_name) != LDAP_SUCCESS) {
		goto cleanup;
	}
	report_stage("ldap_add_ext_s_child_container");
	if (add_organizational_unit(ld, child_dn, child_name) != LDAP_SUCCESS) {
		goto cleanup;
	}
	report_stage("ldap_delete_ext_s_entry");
	if (delete_entry(ld, entry_dn) != LDAP_SUCCESS) {
		goto cleanup;
	}

	report_stage("ldap_result_sync_notification");
	if (wait_for_notification(ld, search_message_id, entry_dn, child_dn,
		timeout_seconds) == 0) {
		probe_status = EXIT_SUCCESS;
	}

cleanup:
	if (sync_ber != NULL) {
		ber_free(sync_ber, 1);
	}

	if (ld != NULL && search_message_id >= 0 && probe_status == EXIT_SUCCESS) {
		if (cancel_sync_search) {
			report_stage("ldap_cancel_s");
			rc = ldap_cancel_s(ld, search_message_id, NULL, NULL);
			if (rc != LDAP_SUCCESS) {
				report_ldap_error("ldap_cancel_s", rc);
				probe_status = EXIT_FAILURE;
			} else {
				fprintf(stderr, "C-SYNCPROBE cancelled Sync search\n");
			}
		} else {
			report_stage("ldap_abandon_ext");
			rc = ldap_abandon_ext(ld, search_message_id, NULL, NULL);
			if (rc != LDAP_SUCCESS) {
				report_ldap_error("ldap_abandon_ext", rc);
				probe_status = EXIT_FAILURE;
			} else {
				fprintf(stderr, "C-SYNCPROBE abandoned Sync search\n");
			}
		}
	}

	if (ld != NULL) {
		report_stage("cleanup_delete_entry");
		(void)delete_entry(ld, entry_dn);
		report_stage("cleanup_delete_child_container");
		(void)delete_entry(ld, child_dn);
		report_stage("cleanup_delete_test_container");
		(void)delete_entry(ld, container_dn);
		ldap_unbind_ext_s(ld, NULL, NULL);
	}

	if (probe_status == EXIT_SUCCESS) {
		fprintf(stderr, "C-SYNCPROBE PASS\n");
	} else {
		fprintf(stderr, "C-SYNCPROBE FAIL\n");
	}
	return probe_status;
}
