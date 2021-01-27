# Release Branches

## Updating Release Branches

When a new release is promoted to either the beta or stable channel, the
corresponding field in `infra/config/lib/release_branches/branches.json` should
be kept up to date, and re-generate the repository's config by executing
`infra/config/main.star`.

## Updating ProtoBuf

After editing the protobuf, run the command:

```
protoc --descriptor_set_out=./branches.bin ./branches.proto
```

And check in the updated `branches.bin` file.
