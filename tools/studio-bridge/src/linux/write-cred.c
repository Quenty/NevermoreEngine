#include <windows.h>
#include <wincred.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[]) {
    if (argc < 3) {
        printf("Usage: write-cred.exe <target_name> <credential_value>\n");
        printf("Example: write-cred.exe \"RobloxStudioAuth.ROBLOSECURITY\" \"cookie_value\"\n");
        return 1;
    }
    
    const char *target = argv[1];
    const char *value = argv[2];
    
    // Convert to wide strings
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
        printf("CredWriteW failed: %lu\n", GetLastError());
        free(wtarget);
        return 1;
    }
    
    printf("Credential written: target='%s', value_len=%d\n", target, (int)strlen(value));
    
    // Verify by reading back
    PCREDENTIALW pcred = NULL;
    if (CredReadW(wtarget, CRED_TYPE_GENERIC, 0, &pcred)) {
        printf("Read back: blob_size=%lu\n", pcred->CredentialBlobSize);
        CredFree(pcred);
    } else {
        printf("CredReadW failed: %lu\n", GetLastError());
    }
    
    free(wtarget);
    return 0;
}
