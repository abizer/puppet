# A free-form text attribute on a Mesos agent.
#
# For example, the "nfs" attribute can tag whether a agent has NFS available,
# and tasks can pin themselves to hosts with the "nfs:true" attribute.
#
# Note that changing attributes results in "incompatible agent info" and
# requires the agent's entire config to be deleted.
# http://www.flexthinker.com/2015/09/reconfiguring-mesos-agents-agents-with-new-resources/
define ocf_mesos::agent::attribute($value) {
  if tagged('ocf_mesos::agent') {
    concat::fragment { "mesos-agent attribute: ${title}":
      content => "${title}:${value}",
      target  => '/etc/mesos-agent/attributes',
    }
  }
}
