kubectl apply -f k8s.yml


pod=$(kubectl get serviceaccount gitlab -n gitlab -o json | jq -r '.secrets[0].name')

kubectl get secret ${pod} -n gitlab -o json | jq -r '.data["ca.crt"]' | base64 -d
kubectl get secret ${pod} -n gitlab -o json | jq -r '.data.token' | base64 -d
