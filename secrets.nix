let
  # Replace these placeholder AGE public keys with the real keys for the machines
  # that should be able to decrypt your secrets. Generate a key pair with:
  #
  #   ssh-keygen -t ed25519 -f /persist/ssh/ssh_host_ed25519_key
  #
  # Then convert the public key into an age recipient string:
  #
  #   nix shell nixpkgs#age --command ssh-to-age -i /persist/ssh/ssh_host_ed25519_key.pub
  #
  recipients = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAk+MsD6yeXT3dh2hNSYdGONxWS8yILJe1Me/MveOPwQ acrogenesis@MacBookPro"
  ];

  mkSecret = path: {
    name = path;
    value = { publicKeys = recipients; };
  };

  secrets = map mkSecret [
    # "../nix-private/adiosBotToken.age"
    # "../nix-private/borgBackupKey.age"
    # "../nix-private/borgBackupSSHKey.age"
    # "../nix-private/bwSession.age"
    "../nix-private/grafanaSecretKey.age"
    "../nix-private/cloudflareDnsApiCredentials.age"
    "../nix-private/cloudflareFirewallApiKey.age"
    # "../nix-private/duckDNSDomain.age"
    # "../nix-private/duckDNSToken.age"
    # "../nix-private/gitIncludes.age"
    "../nix-private/hashedUserPassword.age"
    # "../nix-private/invoicePlaneDbPasswordFile.age"
    "../nix-private/keycloakCloudflared.age"
    "../nix-private/keycloakDbPasswordFile.age"
    # "../nix-private/matrixRegistrationSecret.age"
    "../nix-private/microbinCloudflared.age"
    "../nix-private/audiobookshelfCloudflared.age"
    "../nix-private/jellyfinCloudflared.age"
    "../nix-private/minifluxAdminPassword.age"
    "../nix-private/minifluxCloudflared.age"
    "../nix-private/rfccheckCloudflared.age"
    "../nix-private/rfccheckEnv.age"
    "../nix-private/navidromeCloudflared.age"
    # "../nix-private/navidromeEnv.age"
    "../nix-private/networks.nix"
    "../nix-private/nextcloudAdminPassword.age"
    "../nix-private/nextcloudCloudflared.age"
    "../nix-private/paperlessPassword.age"
    "../nix-private/paperlessWebdav.age"
    # "../nix-private/plausibleSecretKeybaseFile.age"
    # "../nix-private/radicaleHtpasswd.age"
    "../nix-private/resticBackblazeEnv.age"
    "../nix-private/resticPassword.age"
    "../nix-private/sambaPassword.age"
    "../nix-private/slskdEnvironmentFile.age"
    "../nix-private/teslamateEnv.age"
    "../nix-private/mqttPassword.age"
    "../nix-private/unpackerrEnvironmentFile.age"
    # "../nix-private/smtpPassword.age"
    "../nix-private/tailscaleAuthKey.age"
    # "../nix-private/tgNotifyCredentials.age"
    "../nix-private/nixAccessTokens.age"
    "../nix-private/refunEnv.age"
    "../nix-private/refunCredentials.age"
    "../nix-private/refunEfirmaCer.age"
    "../nix-private/refunEfirmaKey.age"
    "../nix-private/vaultwardenCloudflared.age"
    # "../nix-private/wireguardCredentials.age"
    # "../nix-private/wireguardPrivateKeySpencer.age"
    # "../nix-private/withings2intervals.age"
    # "../nix-private/withings2intervals_authcode.age"
    # "../nix-private/work.nix"
  ];
in builtins.listToAttrs secrets
