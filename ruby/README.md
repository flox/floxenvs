# Ruby

This is a ruby environment for developing using Ruby and Flox.

# The goal

Get the top 15 or so rubygems that have Native Extensions building with Flox.
See `Gemfile` for the list (the commented out ones are broken still)

# Usage

    flox activate
    bundle

# The test

The `test.rb` file tries to load/require all the gem to ensure they at least
can be `required`.

    bundle exec ./test.rb

or
    
    ./test.sh since all environments on flox/floxenvs have a `test.sh` for validation


# Platforms

Tested on Mac aarch64 and Linux x86_64 so far.

# License

MIT
