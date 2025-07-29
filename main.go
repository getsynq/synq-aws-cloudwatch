package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"log"
	"net/url"
	"os"
	"strings"
	"time"

	ingestcloudwatchv1grpc "buf.build/gen/go/getsynq/api/grpc/go/synq/ingest/cloudwatch/v1/cloudwatchv1grpc"
	ingestcloudwatchv1 "buf.build/gen/go/getsynq/api/protocolbuffers/go/synq/ingest/cloudwatch/v1"
	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/protobuf/types/known/timestamppb"
)

var SynqApiEndpoint string = envOrDefault("SYNQ_API_ENDPOINT", "https://developer.synq.io/")
var SynqApiToken string = os.Getenv("SYNQ_TOKEN")
var SynqClientId string = os.Getenv("SYNQ_CLIENT_ID")
var SynqClientSecret string = os.Getenv("SYNQ_CLIENT_SECRET")

var oauthTokenSource TokenSource
var grpcConn *grpc.ClientConn

func init() {

	parsedEndpoint, err := url.Parse(SynqApiEndpoint)
	if err != nil {
		log.Fatal(err)
	}

	if SynqApiToken != "" {
		ts, err := LongLivedTokenSource(SynqApiToken, parsedEndpoint)
		if err != nil {
			log.Fatalf("failed to create token source: %v", err)
		}
		oauthTokenSource = ts
	} else if SynqClientId != "" && SynqClientSecret != "" {
		ts, err := ClientIdSecretTokenSource(SynqClientId, SynqClientSecret, parsedEndpoint)
		if err != nil {
			log.Fatalf("failed to create token source: %v", err)
		}
		oauthTokenSource = ts
	} else {
		log.Fatal("no SYNQ_TOKEN or SYNQ_CLIENT_ID and SYNQ_CLIENT_SECRET provided")
	}

	creds := credentials.NewTLS(&tls.Config{})
	opts := []grpc.DialOption{
		grpc.WithTransportCredentials(creds),
		grpc.WithPerRPCCredentials(oauthTokenSource),
		grpc.WithAuthority(parsedEndpoint.Host),
	}

	port := parsedEndpoint.Port()
	if port == "" {
		port = "443"
	}

	grpcConn, err = grpc.Dial(fmt.Sprintf("%s:%s", parsedEndpoint.Host, port), opts...)
	if err != nil {
		log.Fatalf("failed to dial: %v", err)
	}
}

func handler(ctx context.Context, logsEvent events.CloudwatchLogsEvent) error {
	data, err := logsEvent.AWSLogs.Parse()
	if err != nil {
		return err
	}

	cloudwatchServiceClient := ingestcloudwatchv1grpc.NewCloudwatchServiceClient(grpcConn)

	req := &ingestcloudwatchv1.IngestCloudwatchLogsDataRequest{
		Owner:               data.Owner,
		LogGroup:            data.LogGroup,
		LogStream:           data.LogStream,
		SubscriptionFilters: data.SubscriptionFilters,
		MessageType:         data.MessageType,
	}

	for _, logEvent := range data.LogEvents {
		cleanedMessage := strings.ToValidUTF8(logEvent.Message, "")
		event := &ingestcloudwatchv1.CloudwatchLogsLogEvent{
			Id:        logEvent.ID,
			Timestamp: timestamppb.New(time.UnixMilli(logEvent.Timestamp)),
			Message:   cleanedMessage,
		}
		req.LogEvents = append(req.LogEvents, event)
	}

	log.Printf("Ingesting %d log events for log_group=%s log_stream=%s", len(data.LogEvents), data.LogGroup, data.LogStream)

	_, err = cloudwatchServiceClient.IngestCloudwatchLogsData(ctx, req)
	if err != nil {
		log.Printf("failed to ingest logs: %v", err)
		return err
	}

	return nil
}

func main() {
	defer grpcConn.Close()

	lambda.Start(handler)
}

func envOrDefault(envVarName string, def string) string {
	ret := os.Getenv(envVarName)
	if ret == "" {
		return def
	}
	return ret
}
