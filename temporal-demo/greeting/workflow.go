package greeting

import (
	"time"

	"go.temporal.io/sdk/workflow"
)

func SayHelloWorkflow(
	ctx workflow.Context,
	name string,
) (string, error) {
	ctx = workflow.WithActivityOptions(
		ctx,
		workflow.ActivityOptions{
			StartToCloseTimeout: 10 * time.Second,
		},
	)

	var result string
	err := workflow.ExecuteActivity(
		ctx, Greet, name,
	).Get(ctx, &result)
	if err != nil {
		return "", err
	}
	return result, nil
}
