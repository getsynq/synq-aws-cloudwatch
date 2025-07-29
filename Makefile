.DEFAULT_GOAL := zip


.PHONY: bootstrap # Push the image to the remote registry
bootstrap:
	GOOS=linux GOARCH=amd64 go build -tags lambda.norpc -o bootstrap ./

.PHONY: bootstrap-arm64 # Push the image to the remote registry
bootstrap-arm64:
	GOOS=linux GOARCH=arm64 go build -tags lambda.norpc -o bootstrap ./

.PHONY: zip
zip: bootstrap
	rm -f synq-aws-cloudwatch.zip
	zip synq-aws-cloudwatch.zip bootstrap


.PHONY: run
run:
	go run ./