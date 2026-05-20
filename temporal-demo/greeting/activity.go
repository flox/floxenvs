package greeting

import (
	"context"
	"fmt"
)

func Greet(ctx context.Context, name string) (string, error) {
	return fmt.Sprintf("Hello %s", name), nil
}
