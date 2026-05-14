#include <windows.h>
#include <wincred.h>
#include <stdio.h>
#include <string.h>

/**
 * Write one or more credentials to the Windows Credential Manager.
 * Accepts pairs of arguments: <target> <value> [<target> <value> ...]
 * This batching avoids repeated Wine process startup overhead.
 */
int main(int argc, char *argv[]) {
    if (argc < 3 || (argc - 1) % 2 != 0) {
        printf("Usage: write-cred.exe <target> <value> [<target> <value> ...]\n");
        printf("Example: write-cred.exe \"target1\" \"val1\" \"target2\" \"val2\"\n");
        return 1;
    }

    int pairs = (argc - 1) / 2;
    int failures = 0;

    for (int i = 0; i < pairs; i++) {
        const char *target = argv[1 + i * 2];
        const char *value = argv[2 + i * 2];

        int tlen = MultiByteToWideChar(CP_UTF8, 0, target, -1, NULL, 0);
        WCHAR *wtarget = (WCHAR *)malloc(tlen * sizeof(WCHAR));
        MultiByteToWideChar(CP_UTF8, 0, target, -1, wtarget, tlen);

        CREDENTIALW cred;
        memset(&cred, 0, sizeof(cred));
        cred.Type = CRED_TYPE_GENERIC;
        cred.TargetName = wtarget;
        cred.CredentialBlobSize = (DWORD)strlen(value);
        cred.CredentialBlob = (BYTE *)value;
        cred.Persist = CRED_PERSIST_LOCAL_MACHINE;

        if (!CredWriteW(&cred, 0)) {
            printf("CredWriteW failed for '%s': %lu\n", target, GetLastError());
            failures++;
        } else {
            printf("Credential written: target='%s', value_len=%d\n", target, (int)strlen(value));
        }

        free(wtarget);
    }

    return failures > 0 ? 1 : 0;
}
