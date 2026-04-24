{ config, lib, ... }:
let
  cfg = config.routeros.scheduler;

  schedulerType = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.anything;
    options = {
      onEvent = lib.mkOption {
        type = lib.types.str;
        description = "Script source executed when the scheduler fires.";
      };
      interval = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Interval between runs (e.g. \"30s\", \"1d\"). Null disables interval scheduling.";
      };
      startTime = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Start time (e.g. \"05:22:11\" or \"startup\").";
      };
      startDate = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Start date (e.g. \"2026-01-01\").";
      };
      policy = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "ftp"
          "reboot"
          "read"
          "write"
          "policy"
          "test"
          "password"
          "sniff"
          "sensitive"
          "romon"
        ];
        description = "RouterOS permission policies the script runs with.";
      };
      disabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disable this scheduler entry without removing it.";
      };
      comment = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
    };
  };
in
{
  options.routeros.scheduler = lib.mkOption {
    type = lib.types.attrsOf schedulerType;
    default = { };
    description = ''
      Scheduled tasks (`/system scheduler`), keyed by task name.
    '';
    example = lib.literalExpression ''
      {
        kuma-heartbeat = {
          interval = "30s";
          onEvent = "/tool fetch url=\"https://status.example.com/api/push/foo\" mode=http";
          startTime = "00:00:00";
        };
      }
    '';
  };

  config = lib.mkIf (cfg != { }) {
    resource.routeros_system_scheduler = lib.mapAttrs (
      taskName: task:
      let
        base = {
          name = taskName;
          on_event = task.onEvent;
          policy = task.policy;
          disabled = task.disabled;
        }
        // lib.optionalAttrs (task.interval != null) {
          interval = task.interval;
        }
        // lib.optionalAttrs (task.startTime != null) {
          start_time = task.startTime;
        }
        // lib.optionalAttrs (task.startDate != null) {
          start_date = task.startDate;
        }
        // lib.optionalAttrs (task.comment != "") {
          comment = task.comment;
        };
        extras = builtins.removeAttrs task [
          "onEvent"
          "interval"
          "startTime"
          "startDate"
          "policy"
          "disabled"
          "comment"
        ];
      in
      base // extras
    ) cfg;
  };
}
