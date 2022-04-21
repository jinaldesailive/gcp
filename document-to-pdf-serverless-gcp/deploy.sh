#Build the solution
gcloud builds submit --tag gcr.io/$GOOGLE_CLOUD_PROJECT/pdf-converter
#Deploy the solution to the Cloud Run
gcloud run deploy pdf-converter \
--image gcr.io/$GOOGLE_CLOUD_PROJECT/pdf-converter \
--platform managed \
--region us-central1 \
--memory=2Gi \
--no-allow-unauthenticated \
--max-instances=1 \
--set-env-vars PDF_BUCKET=$GOOGLE_CLOUD_PROJECT-pdf
#Get the service url
SERVICE_URL=$(gcloud beta run services describe pdf-converter --platform managed --region us-central1 --format="value(status.url)")
echo $SERVICE_URL
#Curl the service url
curl -X POST -H "Authorization: Bearer $(gcloud auth print-identity-token)" $SERVICE_URL
#Create the upload bucket
gsutil mb gs://$GOOGLE_CLOUD_PROJECT-upload
#Create the pdf bucket
gsutil mb gs://$GOOGLE_CLOUD_PROJECT-pdf
#Create notification on the upload bucket, so that it will send a pub/sub when new document uploaded
gsutil notification create -t new-doc -f json \
-e OBJECT_FINALIZE gs://$GOOGLE_CLOUD_PROJECT-upload
#Create service account for pub/sub to trigger the Cloud Run service
gcloud iam service-accounts create pubsub-cloud-run-invoker \
--display-name "PubSub Cloud Run Invoker"
#Assign role to invoke PDF Converter service
gcloud beta run services add-iam-policy-binding pdf-converter \
--member=serviceAccount:pubsub-cloud-run-invoker@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com \
--role=roles/run.invoker \
--platform managed \
--region us-central1
#Get the current project name
PROJECT=$(gcloud config get-value project)
#Get the current project number
PROJECT_NUMBER=$(gcloud projects list --filter="$PROJECT" --format="value(PROJECT_NUMBER)")
#Enable project to create pub/sub auth token
gcloud projects add-iam-policy-binding $GOOGLE_CLOUD_PROJECT \
--member=serviceAccount:service-$PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com \
--role=roles/iam.serviceAccountTokenCreator
#Create a pub/sub subscription, so that PDF Converter service can run whenever new pub/sub message is published
gcloud beta pubsub subscriptions create pdf-conv-sub \
--topic new-doc \
--push-endpoint=$SERVICE_URL \
--push-auth-service-account=pubsub-cloud-run-invoker@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com