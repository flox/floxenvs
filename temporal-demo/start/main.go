package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"flox.dev/temporal-demo/greeting"

	"go.temporal.io/sdk/client"
)

func main() {
	if len(os.Args) < 2 {
		log.Fatalln("Usage: go run ./start <name>")
	}

	c, err := client.Dial(client.Options{})
	if err != nil {
		log.Fatalln("Unable to create client", err)
	}
	defer c.Close()

	options := client.StartWorkflowOptions{
		ID: fmt.Sprintf(
			"greeting-workflow-%d",
			time.Now().UnixNano(),
		),
		TaskQueue: "my-task-queue",
	}

	we, err := c.ExecuteWorkflow(
		context.Background(),
		options,
		greeting.SayHelloWorkflow,
		os.Args[1],
	)
	if err != nil {
		log.Fatalln("Unable to execute workflow", err)
	}
	log.Println(
		"Started workflow",
		"WorkflowID", we.GetID(),
		"RunID", we.GetRunID(),
	)

	var result string
	err = we.Get(context.Background(), &result)
	if err != nil {
		log.Fatalln("Unable to get workflow result", err)
	}
	log.Println("Workflow result:", result)
}
