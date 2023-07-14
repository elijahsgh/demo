provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "minikube"
  }
}

provider "harness" {
  endpoint         = "https://app.harness.io/gateway"
  account_id       = var.harness_terraform_account_id
  platform_api_key = var.harness_terraform_api_key
}

resource "kubernetes_namespace" "dev" {
  metadata {
    name = "dev"
  }
}

resource "kubernetes_namespace" "stage" {
  metadata {
    name = "stage"
  }
}

resource "kubernetes_namespace" "prod" {
  metadata {
    name = "prod"
  }
}

resource "kubernetes_namespace" "harness_delegate_namespace" {
  metadata {
    name = var.harness_delegate_namespace
  }
}

resource "helm_release" "harness_delegate" {
  name       = "harness-delegate"
  repository = "https://app.harness.io/storage/harness-download/delegate-helm-chart/"
  chart      = "harness-delegate-ng"
  version    = "= 1.0.11"
  namespace  = kubernetes_namespace.harness_delegate_namespace.metadata[0].name

  set {
    name  = "delegateName"
    value = var.harness_delegate_name
  }

  set {
    name  = "accountId"
    value = var.harness_delegate_account_id
  }

  set {
    name  = "delegateToken"
    value = var.harness_delegate_token
  }

  set {
    name  = "managerEndpoint"
    value = var.harness_delegate_manager_endpoint
  }

  set {
    name  = "delegateDockerImage"
    value = var.harness_delegate_docker_image
  }

  set {
    name  = "replicas"
    value = var.harness_delegate_replicas
  }

  set {
    name  = "upgrader.enabled"
    value = var.harness_delegate_upgrader_enabled
  }

  set {
    name  = "tags"
    value = "demo"
  }

  # prevent the helm provider from updating the chart after initial deployment
  lifecycle {
    ignore_changes = all
  }
}

resource "harness_platform_connector_oci_helm" "docker_oci_registry" {
  identifier  = "docker_oci_registry"
  name        = "Docker OCI Registry"
  description = "Docker OCI Registry"

  org_id     = "default"
  project_id = "default_project"

  url = "oci://registry-1.docker.io"
}

resource "harness_platform_service" "harness_service_nginx" {
  identifier  = "nginx"
  name        = "nginx"
  description = "Deployment of nginx"
  org_id      = "default"
  project_id  = "default_project"

  yaml = <<-EOT
        service:
            name: nginx
            identifier: nginx
            orgIdentifier: default
            projectIdentifier: default_project
            gitOpsEnabled: false
            serviceDefinition:
                type: NativeHelm
                spec:
                    manifests:
                        - manifest:
                            identifier: nginx
                            type: HelmChart
                            spec:
                                store:
                                    type: OciHelmChart
                                    spec:
                                        config:
                                            type: Generic
                                            spec:
                                                connectorRef: ${harness_platform_connector_oci_helm.docker_oci_registry.identifier}
                                        basePath: bitnamicharts
                                        version: <+input>
                                chartName: nginx
    EOT
}

resource "harness_platform_connector_kubernetes" "minikube_connector" {
  identifier  = "minikube_connector"
  name        = "minikube connector"
  description = "Connector for minikube"

  inherit_from_delegate {
    delegate_selectors = ["demo"]
  }
}

resource "harness_platform_environment" "demo_env_dev" {
  identifier = "dev"
  name       = "dev"
  org_id     = "default"
  project_id = "default_project"
  type       = "PreProduction"

  yaml = <<-EOT
        environment:
            name: dev
            identifier: dev
            tags: {}
            type: PreProduction
            orgIdentifier: default
            projectIdentifier: default_project
            variables: []    
    EOT
}

resource "harness_platform_infrastructure" "demo_infra_dev" {
  identifier = "demo_infra_dev"
  name       = "demo_infra_dev"
  org_id     = "default"
  project_id = "default_project"
  type       = "KubernetesDirect"
  env_id     = harness_platform_environment.demo_env_dev.identifier
  yaml       = <<-EOT
        infrastructureDefinition:
            name: demo_infra_dev
            identifier: demo_infra_dev
            description: ""
            tags: {}
            orgIdentifier: default
            projectIdentifier: default_project
            deploymentType: NativeHelm
            type: KubernetesDirect
            spec:
                connectorRef: account.${harness_platform_connector_kubernetes.minikube_connector.identifier}
                releaseName: release-<+INFRA_KEY>
                namespace: dev
            allowSimultaneousDeployments: true
    EOT
}

resource "harness_platform_environment" "demo_env_stage" {
  identifier = "stage"
  name       = "stage"
  org_id     = "default"
  project_id = "default_project"
  type       = "PreProduction"

  yaml = <<-EOT
        environment:
            name: stage
            identifier: stage
            tags: {}
            type: PreProduction
            orgIdentifier: default
            projectIdentifier: default_project
            variables: []    
    EOT
}

resource "harness_platform_infrastructure" "demo_infra_stage" {
  identifier = "demo_infra_stage"
  name       = "demo_infra_stage"
  org_id     = "default"
  project_id = "default_project"
  type       = "KubernetesDirect"
  env_id     = harness_platform_environment.demo_env_stage.identifier
  yaml       = <<-EOT
        infrastructureDefinition:
            name: demo_infra_stage
            identifier: demo_infra_stage
            description: ""
            tags: {}
            orgIdentifier: default
            projectIdentifier: default_project
            deploymentType: NativeHelm
            type: KubernetesDirect
            spec:
                connectorRef: account.${harness_platform_connector_kubernetes.minikube_connector.identifier}
                releaseName: release-<+INFRA_KEY>
                namespace: stage
            allowSimultaneousDeployments: true
    EOT
}

resource "harness_platform_environment" "demo_env_prod" {
  identifier = "prod"
  name       = "prod"
  org_id     = "default"
  project_id = "default_project"
  type       = "Production"

  yaml = <<-EOT
        environment:
            name: prod
            identifier: prod
            tags: {}
            type: Production
            orgIdentifier: default
            projectIdentifier: default_project
            variables: []    
    EOT
}

resource "harness_platform_infrastructure" "demo_infra_prod" {
  identifier = "demo_infra_prod"
  name       = "demo_infra_prod"
  org_id     = "default"
  project_id = "default_project"
  type       = "KubernetesDirect"
  env_id     = harness_platform_environment.demo_env_prod.identifier
  yaml       = <<-EOT
        infrastructureDefinition:
            name: demo_infra_prod
            identifier: demo_infra_prod
            description: ""
            tags: {}
            orgIdentifier: default
            projectIdentifier: default_project
            deploymentType: NativeHelm
            type: KubernetesDirect
            spec:
                connectorRef: account.${harness_platform_connector_kubernetes.minikube_connector.identifier}
                releaseName: release-<+INFRA_KEY>
                namespace: prod
            allowSimultaneousDeployments: true
    EOT
}

resource "harness_platform_pipeline" "demo_pipeline_nginx_dev" {
  identifier       = "demo_pipeline_dev"
  name             = "demo_pipeline_dev"
  org_id           = "default"
  project_id       = "default_project"
  template_applied = false
  yaml             = <<-EOT
        pipeline:
          name: demo_pipeline_dev
          identifier: demo_pipeline_dev
          projectIdentifier: default_project
          orgIdentifier: default
          variables:
          - name: nginx_version
            type: String
            description: ""
            required: false
            value: 15.1.0
          stages:
            - stage:
                name: deploy_nginx
                identifier: deploy_nginx
                description: "Deploy nginx"
                type: Deployment
                spec:
                  deploymentType: NativeHelm
                  service:
                    serviceRef: nginx
                  environment:
                    environmentRef: ${harness_platform_environment.demo_env_dev.identifier}
                    deployToAll: false
                    infrastructureDefinitions:
                      - identifier: ${harness_platform_infrastructure.demo_infra_dev.identifier}
                  execution:
                    steps:
                      - step:
                          name: Helm Deployment
                          identifier: helmDeployment
                          type: HelmDeploy
                          timeout: 10m
                          spec:
                            skipDryRun: false
                    rollbackSteps:
                      - step:
                          name: Helm Rollback
                          identifier: helmRollback
                          type: HelmRollback
                          timeout: 10m
                          spec: {}
                tags: {}
                failureStrategies:
                  - onFailure:
                      errors:
                        - AllErrors
                      action:
                        type: StageRollback
    EOT
}

resource "harness_platform_pipeline" "demo_pipeline_nginx_stage" {
  identifier       = "demo_pipeline_stage"
  name             = "demo_pipeline_stage"
  org_id           = "default"
  project_id       = "default_project"
  template_applied = false
  yaml             = <<-EOT
        pipeline:
          name: demo_pipeline_stage
          identifier: demo_pipeline_stage
          projectIdentifier: default_project
          orgIdentifier: default
          stages:
            - stage:
                name: deploy_nginx
                identifier: deploy_nginx
                description: "Deploy nginx"
                type: Deployment
                spec:
                  deploymentType: NativeHelm
                  service:
                    serviceRef: nginx
                  environment:
                    environmentRef: ${harness_platform_environment.demo_env_stage.identifier}
                    deployToAll: false
                    infrastructureDefinitions:
                      - identifier: ${harness_platform_infrastructure.demo_infra_stage.identifier}
                  execution:
                    steps:
                      - step:
                          name: Helm Deployment
                          identifier: helmDeployment
                          type: HelmDeploy
                          timeout: 10m
                          spec:
                            skipDryRun: false
                    rollbackSteps:
                      - step:
                          name: Helm Rollback
                          identifier: helmRollback
                          type: HelmRollback
                          timeout: 10m
                          spec: {}
                tags: {}
                failureStrategies:
                  - onFailure:
                      errors:
                        - AllErrors
                      action:
                        type: StageRollback
    EOT
}

resource "harness_platform_pipeline" "demo_pipeline_nginx_prod" {
  identifier       = "demo_pipeline_prod"
  name             = "demo_pipeline_prod"
  org_id           = "default"
  project_id       = "default_project"
  template_applied = false
  yaml             = <<-EOT
        pipeline:
          name: demo_pipeline_prod
          identifier: demo_pipeline_prod
          projectIdentifier: default_project
          orgIdentifier: default
          stages:
            - stage:
                name: approval_prod
                identifier: approval_prod
                description: ""
                type: Approval
                spec:
                    execution:
                        steps:
                        - step:
                            name: Approval
                            identifier: b4675e4d-6b2b-5a86-a5e2-a28f1b4ccd04
                            type: HarnessApproval
                            timeout: 1d
                            spec:
                                approvalMessage: Please review the following information and approve the pipeline progression
                                includePipelineExecutionHistory: true
                                approvers:
                                    userGroups:
                                        - _project_all_users
                                    minimumCount: 1
                                    disallowPipelineExecutor: false
                tags: {}
            - stage:
                name: deploy_nginx
                identifier: deploy_nginx
                description: "Deploy nginx"
                type: Deployment
                spec:
                  deploymentType: NativeHelm
                  service:
                    serviceRef: nginx
                  environment:
                    environmentRef: ${harness_platform_environment.demo_env_prod.identifier}
                    deployToAll: false
                    infrastructureDefinitions:
                      - identifier: ${harness_platform_infrastructure.demo_infra_prod.identifier}
                  execution:
                    steps:
                      - step:
                          name: Helm Deployment
                          identifier: helmDeployment
                          type: HelmDeploy
                          timeout: 10m
                          spec:
                            skipDryRun: false
                    rollbackSteps:
                      - step:
                          name: Helm Rollback
                          identifier: helmRollback
                          type: HelmRollback
                          timeout: 10m
                          spec: {}
                tags: {}
                failureStrategies:
                  - onFailure:
                      errors:
                        - AllErrors
                      action:
                        type: StageRollback
    EOT
}

resource "harness_platform_pipeline" "demo_pipeline_nginx_omni" {
  identifier       = "demo_pipeline_omni"
  name             = "demo_pipeline_omni"
  org_id           = "default"
  project_id       = "default_project"
  template_applied = false
  yaml             = <<-EOT
        pipeline:
          name: demo_pipeline_omni
          identifier: demo_pipeline_omni
          projectIdentifier: default_project
          orgIdentifier: default
          stages:
            - stage:
                name: deploy_nginx_dev
                identifier: deploy_nginx_dev
                description: "Deploy nginx to dev"
                type: Deployment
                spec:
                  deploymentType: NativeHelm
                  service:
                    serviceRef: nginx
                  environment:
                    environmentRef: ${harness_platform_environment.demo_env_dev.identifier}
                    deployToAll: false
                    infrastructureDefinitions:
                      - identifier: ${harness_platform_infrastructure.demo_infra_dev.identifier}
                  execution:
                    steps:
                      - step:
                          name: Helm Deployment
                          identifier: helmDeployment
                          type: HelmDeploy
                          timeout: 10m
                          spec:
                            skipDryRun: false
                    rollbackSteps:
                      - step:
                          name: Helm Rollback
                          identifier: helmRollback
                          type: HelmRollback
                          timeout: 10m
                          spec: {}
                tags: {}
                failureStrategies:
                  - onFailure:
                      errors:
                        - AllErrors
                      action:
                        type: StageRollback
            - stage:
                name: deploy_nginx_stage
                identifier: deploy_nginx_stage
                description: "Deploy nginx to stage"
                type: Deployment
                spec:
                  deploymentType: NativeHelm
                  service:
                    serviceRef: nginx
                  environment:
                    environmentRef: ${harness_platform_environment.demo_env_stage.identifier}
                    deployToAll: false
                    infrastructureDefinitions:
                      - identifier: ${harness_platform_infrastructure.demo_infra_stage.identifier}
                  execution:
                    steps:
                      - step:
                          name: Helm Deployment
                          identifier: helmDeployment
                          type: HelmDeploy
                          timeout: 10m
                          spec:
                            skipDryRun: false
                    rollbackSteps:
                      - step:
                          name: Helm Rollback
                          identifier: helmRollback
                          type: HelmRollback
                          timeout: 10m
                          spec: {}
                tags: {}
                failureStrategies:
                  - onFailure:
                      errors:
                        - AllErrors
                      action:
                        type: StageRollback
                when:
                    pipelineStatus: Success
            - stage:
                name: approval_prod
                identifier: approval_prod
                description: ""
                type: Approval
                spec:
                    execution:
                        steps:
                        - step:
                            name: Approval
                            identifier: b4675e4d-6b2b-5a86-a5e2-a28f1b4ccd04
                            type: HarnessApproval
                            timeout: 1d
                            spec:
                                approvalMessage: Please review the following information and approve the pipeline progression
                                includePipelineExecutionHistory: true
                                approvers:
                                    userGroups:
                                        - _project_all_users
                                    minimumCount: 1
                                    disallowPipelineExecutor: false
                tags: {}
                when:
                    pipelineStatus: Success

            - stage:
                name: deploy_nginx_prod
                identifier: deploy_nginx_prod
                description: "Deploy nginx to prod"
                type: Deployment
                spec:
                  deploymentType: NativeHelm
                  service:
                    serviceRef: nginx
                  environment:
                    environmentRef: ${harness_platform_environment.demo_env_prod.identifier}
                    deployToAll: false
                    infrastructureDefinitions:
                      - identifier: ${harness_platform_infrastructure.demo_infra_prod.identifier}
                  execution:
                    steps:
                      - step:
                          name: Helm Deployment
                          identifier: helmDeployment
                          type: HelmDeploy
                          timeout: 10m
                          spec:
                            skipDryRun: false
                    rollbackSteps:
                      - step:
                          name: Helm Rollback
                          identifier: helmRollback
                          type: HelmRollback
                          timeout: 10m
                          spec: {}
                tags: {}
                failureStrategies:
                  - onFailure:
                      errors:
                        - AllErrors
                      action:
                        type: StageRollback
                when:
                    pipelineStatus: Success



    EOT
}
