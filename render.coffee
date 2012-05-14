Async   = require("async")
Request = require("request")
Sugar   = require("sugar")
Less    = require("less")
File    = require("fs")

require("eco")
index = require("./src/index")


# Retrieve organization members in alphabetical order.
retrieveMembers = ({ organization, minWatchers, memberRepos }, callback)->
  Request.get "https://api.github.com/orgs/#{organization}/members", (error, response, body)->
    if error
      throw error

    # At this point we get member login, we also want their name, URL and repos
    members = JSON.parse(body)
    Async.map members, (member, done)->
      Request.get "https://api.github.com/users/#{member.login}", (error, response, body)->
        if error
          done error
        else if response.statusCode == 200
          done null, JSON.parse(body)
        else
          done null, member
    , (error, members)->
      if error
        throw error

      # Lets also retrieve all their interesting repos
      Async.map members, (member, done)->
        Request.get "https://api.github.com/users/#{member.login}/repos", (error, response, body)->
          if error
            done error
          else
            if response.statusCode == 200
              repos = JSON.parse(body)
              # We're only interested in member's own repos, no forks, and one
              # with substantial watchers, sorted by watchers.
              member.repos = repos.
                filter((repo)-> !repo.fork).
                filter((repo)-> repo.watchers >= minWatchers).
                sort((a,b)-> b.watchers - a.watchers).
                slice(0, memberRepos)
            done null, member
      , (error, members)->
        if error
          throw error
        callback members.sort((a, b)-> a.name >= b.name)


# Retrieve organization repositories that have more than minimum number of
# watchers, return sorted by popularity.
retrieveOrgRepos = ({ organization, minWatchers, topRepos }, members, callback)->
  Request.get "https://api.github.com/orgs/#{organization}/repos", (error, response, body)->
    if error
      throw error
    # Filter organization's own repositories by watchers.
    repos = JSON.parse(body).
      filter((repo)-> !repo.fork).
      filter((repo)-> repo.watchers >= minWatchers)
    # Merge with member repositories
    for member in members
      repos = repos.concat(member.repos)
    # And callback with the sorted set
    top = repos.
      sort((a,b)-> b.watchers - a.watchers).
      slice(0, topRepos)
    callback top


# Retrieve organization and member repositories and pass the following object to
# callback:
# members - Array of members with repositories, sorted alphabetically
# repos   - Array of organization and member repositories, sorted by watchers
#
# For each member you get:
# login       - Github login
# name        - Member name
# html_url    - URL for their Github page
# avatar_url  - Gravatar URL
# repos       - Interesting repositories, sorted by most watched first
#
# Each member repository includes:
# name     - Repository name
# homepage - Homepage URL (nor necessarily same as repository)
# html_url - URL for Github page
# watchers - Number of watchers
# forkers  - Number of forkers
retrieve = (options, callback)->
  retrieveMembers options, (members)->
    retrieveOrgRepos options, members, (repos)->
      callback repos: repos, members: members


options =
  organization: "demandforce"
  minWatchers:  5
  topRepos:     6
  memberRepos:  5


# Retrieve what we need and render it to stdout.
retrieve options, (result)->
  html = index(data)
  process.stdout.write html
