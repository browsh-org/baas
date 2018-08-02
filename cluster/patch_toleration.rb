# Remember to use this in terraform-provider-kubernetes/kubernetes/resource_kubernetes_deployment.go:373
# if name == "browsh-http-server" || name == "browsh-ssh-server" {
#		cmd := "echo '" + string(data) + "' | ruby cluster/patch_toleration.rb"
#		output, err := exec.Command("bash", "-c", cmd).Output()
#		if err != nil {
#			panic("tombh hack failed")
#		}
#		data = output
#	}

require 'json'

# raw = '[{"path":"/spec","value":{"replicas":2,"selector":{"matchLabels":{"app":"browsh-http-server"}},"template":{"metadata":{"creationTimestamp":null,"labels":{"app":"browsh-http-server"}},"spec":{"containers":[{"name":"app","image":"tombh/texttop:v1.1.2","command":["/app/browsh","-http-server","-debug"],"ports":[{"containerPort":4333,"protocol":"TCP"}],"resources":{},"terminationMessagePath":"/dev/termination-log","imagePullPolicy":"IfNotPresent"}],"restartPolicy":"Always","terminationGracePeriodSeconds":30,"dnsPolicy":"ClusterFirst","nodeSelector":{"node-type":"preemptible"},"automountServiceAccountToken":true}},"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":"25%","maxSurge":"25%"}},"revisionHistoryLimit":10,"progressDeadlineSeconds":600},"op":"replace"}]'
# File.open('tfspec.txt', 'w') { |file| file.write(raw) }
raw = STDIN.read

json = JSON.parse(raw)
# puts JSON.pretty_generate()
json[0]['value']['template']['spec']['tolerations'] = [{
  key:      'life_time',
  operator: 'Equal',
  value:    'preemptible',
  effect:   'NoSchedule'
}]

puts JSON.dump(json)
