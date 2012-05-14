Async   = require("async")
Request = require("request")
Sugar   = require("sugar")
Less    = require("less")
File    = require("fs")

require("eco")
index = require("./src/index")


# TODO: These should be set from the command line
options =
  organization: "demandforce"
  topRepos:     6


# Retrieve organization members in alphabetical order.
retrieveMembers = ({ organization }, callback)->
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

      # Lets also retrieve all their repos, these will be included in the finale
      # list
      Async.map members, (member, done)->
        Request.get "https://api.github.com/users/#{member.login}/repos", (error, response, body)->
          if error
            done error
          else
            if response.statusCode == 200
              repos = JSON.parse(body)
              # We're only interested in member's own repos, no forks; sorted by
              # watchers.
              member.repos = repos
                .filter((repo)-> !repo.fork)
                .sort((a,b)-> b.watchers - a.watchers)
            done null, member
      , (error, members)->
        if error
          throw error
        # Pass members list, sorted alphabetically.
        callback members.sort((a, b)-> a.name >= b.name)


# Retrieve organization repositories, merge with member repositories, pass to
# callback sorted by most watched.
retrieveOrgRepos = ({ organization }, members, callback)->
  Request.get "https://api.github.com/orgs/#{organization}/repos", (error, response, body)->
    if error
      throw error
    # Filter organization's own repositories.
    repos = JSON.parse(body).filter((repo)-> !repo.fork)
    # Merge with member repositories
    for member in members
      repos = repos.concat(member.repos)
    # Sort from most to least watched
    repos = repos.sort((a,b)-> b.watchers - a.watchers)
    callback repos


retrieveContributors = (repos, members, callback)->
  # Let's find all the contributors
  Async.reduce repos, [], (contributors, repo, done)->
    Request.get "#{repo.url}/contributors", (error, response, body)->
      if error
        done error
      else
        for contributor in JSON.parse(body)
          if members.find((member)-> member.login == contributor.login)
            contributors.push contributor
        done null, contributors
  , (error, contributors)->
    if error
      throw error
    # First, remove all duplicates. Calling .unique() doesn't work because we
    # have distinct objects here.
    contributors = contributors
      .reduce((map, member)->
        map[member.login] = member
        return map
      , {})
    contributors = Object.values(contributors)
      .sort((a, b)-> a.name >= b.name)
    callback contributors


# Retrieve organization and member repositories and pass the following object to
# callback:
# members       - Array of members with repositories, sorted alphabetically
# repos         - Array of organization and member repositories, sorted by watchers
# contributors  - Organization members that either have a repository or
#                 are contributors to one, sorted alphabetically
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
      retrieveContributors repos, members, (contributors)->
        callback
          repos:        repos.slice(0, options.topRepos)
          members:      members
          contributors: contributors


# Retrieve what we need and render it to stdout.
retrieve options, (result)->
  html = index(result)
  process.stdout.write html
