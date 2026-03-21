{ lib }:
{
  # Sanitize a name for use as a Terraform resource identifier.
  # Replaces `-` and `.` with `_`, prepends `_` if name starts with a digit.
  sanitizeName =
    name:
    let
      sanitized = builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name;
    in
    if builtins.match "[0-9].*" sanitized != null then "_${sanitized}" else sanitized;

  # Derive network address from gateway IP (assumes last octet is the host part).
  # "10.0.0.1" -> "10.0.0.0"
  networkAddress =
    gateway:
    let
      parts = lib.splitString "." gateway;
    in
    "${builtins.elemAt parts 0}.${builtins.elemAt parts 1}.${builtins.elemAt parts 2}.0";

  # Extract prefix length from CIDR notation.
  # "10.0.0.0/24" -> 24
  prefixLength =
    cidr:
    let
      parts = lib.splitString "/" cidr;
    in
    lib.toInt (builtins.elemAt parts 1);
}
