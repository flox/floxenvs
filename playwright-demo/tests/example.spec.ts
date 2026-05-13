import { test, expect } from '@playwright/test';

test('todomvc — add and complete a todo', async ({
  page,
}) => {
  await page.goto('https://demo.playwright.dev/todomvc/');

  const newTodo = page.getByPlaceholder(
    'What needs to be done?',
  );
  await newTodo.fill('Try Flox playwright env');
  await newTodo.press('Enter');

  const items = page.getByTestId('todo-item');
  await expect(items).toHaveCount(1);
  await expect(items.first()).toContainText(
    'Try Flox playwright env',
  );

  await page.getByTestId('todo-item').first()
    .getByRole('checkbox').check();
  await expect(items.first()).toHaveClass(/completed/);
});
