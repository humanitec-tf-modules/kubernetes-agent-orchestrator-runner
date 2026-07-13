moved {
  from = kubernetes_namespace.humanitec_kubernetes_agent_runner
  to   = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner
}

moved {
  from = kubernetes_namespace.humanitec_kubernetes_agent_runner_job
  to   = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job
}

moved {
  from = helm_release.humanitec_kubernetes_agent_runner
  to   = helm_release.platform_orchestrator_kubernetes_agent_runner
}
