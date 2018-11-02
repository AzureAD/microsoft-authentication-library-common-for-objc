# This is a comment.
# Each line is a file pattern followed by one or more owners.

# These owners will be the default owners for everything in
# the repo. Unless a later match takes precedence,
# all here will be requested for
# review when someone opens a pull request.
*       @unpluggedk @antrix1989 @jasoncoolmax @rohitnarula7176 @oldalton

# Order is important; the last matching pattern takes the most
# precedence. When someone opens a pull request that only
# modifies JS files, only @js-owner and not the global
# owner(s) will be requested for a review.
*.md    @brandwe
