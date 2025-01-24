I'm going to be working towards getting a k3s cluster up, I want to document this for future use in a Readme.md in markdown, I'm going to give you each step that I went through and i want you to rephrase it in a better more explanation way, format things nicely, and if necessary separate things into chapters or separate sections, but that's your discretion

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl port-forward svc/argocd-server -n argocd 8080:443

access the tool on localhost:8080
