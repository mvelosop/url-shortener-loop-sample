#!/usr/bin/env bash
# A work session that keeps reporting blocked makes no recorded progress.
# Stop rather than spin.
. "$(dirname "$0")/../lib.sh"
fixture_new
fixture_plan "$PLAN_ONE"
fixture_stub <<STUB
case "\$PHASE" in
  plan) cat > loop/state.json <<'PLANJSON'
$PLAN_ONE
PLANJSON
    ;;
  work) jq -nc --arg t "\$TASK" '{task:\$t,outcome:"blocked",summary:"cannot proceed",files:[],verified:"",notes:"none"}' > loop/proposal.json ;;
esac
STUB
LOOP_MAX_ATTEMPTS=99 LOOP_CONVERGENCE_MIN=99 fixture_run docs/briefs/0003-runstat-cli.md
assert_exit 3
assert_run_status stalled
assert_log "no recorded progress"
finish
