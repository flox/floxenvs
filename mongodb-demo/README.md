# mongodb-demo

Full MongoDB demo environment with an interactive
client and styled terminal UI. Includes the MongoDB
server (via the minimal [mongodb](../mongodb/) layer),
the `mongosh` shell client, and `gum` for formatted
connection info on activation.

For a minimal environment to include in your own
project, see [mongodb](../mongodb/) or use
`flox/mongodb` on FloxHub.

## Quick start

```bash
flox activate -r flox/mongodb-demo --start-services
```

Then connect:

```bash
mongosh --host $MONGO_HOST --port $MONGO_PORT
```

## What this demo includes

- MongoDB Community Edition server
- `mongosh` interactive shell client
- `gum` for styled terminal output
- Automatic data directory creation on activation
- Service definition for background `mongod`
- Connection info display on activation

## Connecting with mongosh

After starting services, connect to the running
instance:

```bash
mongosh --host $MONGO_HOST --port $MONGO_PORT
```

Default connection details:

| Setting | Value |
| ------- | ----- |
| Host | 127.0.0.1 |
| Port | 127017 |

## CRUD walkthrough

Once connected via `mongosh`:

```javascript
// Switch to a database (created on first write)
use("myapp");

// Insert a document
db.items.insertOne({ name: "widget", price: 9.99 });

// Query documents
db.items.find({ name: "widget" });

// Update a document
db.items.updateOne(
  { name: "widget" },
  { $set: { price: 12.99 } }
);

// Delete a document
db.items.deleteOne({ name: "widget" });

// Drop the collection
db.items.drop();
```

## Customizing connection settings

Override vars in your own manifest:

```toml
[vars]
MONGO_PORT = "27017"
MONGO_HOST = "127.0.0.1"
```

## Data directory

MongoDB data is stored in
`$FLOX_ENV_CACHE/mongodb`. This persists across
activations. To start fresh:

```bash
rm -rf "$FLOX_ENV_CACHE/mongodb"
```

## Using the minimal version

If you do not need the demo experience, include
the minimal environment in your own manifest:

```toml
[include]
environments = ["flox/mongodb"]
```

This gives you the MongoDB server with sane defaults.
Override vars and add packages in your own manifest
as needed.

## Service management

```bash
flox services start           # start mongodb
flox services stop            # stop mongodb
flox services status          # check status
flox services logs mongodb    # view logs
```
