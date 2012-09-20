# Grove

A place to store structured documents like comments, blog posts, events etc. and organize these documents for easy retrieval later.

# Data model

A grove document can be any hash that can be represented by a json-record including nesting. In addition to the content, a document has the following features:

## Document class

An application specific class. This can be used to filter queries, and is typically used by applications to determine the content type of the document. A class name is a period delimited string of identifiers and the first identifier must be "post" which indicates to the pebbles ecology that this specific object is handled by Grove. Typical class names include:

- post.blog
- post.event
- post.user_profile

When retrieving a collection of object of disparate types, the class helps the application determine how to display and handle the document.

## Paths

The content of the grove database can be viewed as a hierarchy of folders. Every document must be stored to a path, and paths with wildcards are typically used to query grove for content. A path is a period delimited string of identifiers where the first identifier must be the "realm" of the document (see checkpoint for more on realms). The second identifier is by convention an application identifier while the rest of the path is application specific. Typical paths include

- apdm.bagera.events.facebook
- dna.ditt_forslag.topic_1.suggestions
- apdm.blogs.firda.fotball.postings

A document has one canonical path, which is where the "original" document is stored. If you need the document to appear in multiple places in the folder hierarchy you may create "symlinks" by appending additinal paths to the document. This will make the document appear in query results as if it was stored in all the provided paths, but in reality the original document is always returned. If the underlying document is updated, it will be updated on all paths.

You don't have to create "folders" in grove. Any path you postulate is okay as long as it is within the realm of your application.

### A note on "subpaths"

It is a convention in pebbles applications to put children of an object in a "subfolder" of its canonical path. A subpath is generated by appending the object id of the parent object to the path and storing the children there. E.g.:

    post.blog:apdm.blogs.football$323 # a posting in the football blog (object id = 323)
    post.comment:apdm.blogs.football.323$324 # a comment to the posting (object id appended to path)
    post.comment:apdm.blogs.football.323$5343 # a later comment to the same posting

## Tags

A set og tags may be applied to any document and subsequently be used to constrain results in queries. A tag is an identifier that may contain letters, digits and underscores.

## Occurrences

A document may also be organized on a timeline. A document may have any number of timestamps (occurrences) attached to it. Each timestamp is labeled. This can be used to model start- or end-time for events, or due dates for tasks. When querying grove, the result set can be constrained to documents with a specific labeled occurrence and optionally only documents with such an occurrence within a specified time window. This would typically be used to retrieve events that occur on a specific date, or tasks that are overdue.

## Synchronization from external sources

When synchronizing data from external sources, you should give the document an `external_id`. The external id may be any string, it may e.g. be the url or database id of the source object. The important thing is that it is invariant for the given source object, and that it is unique within the realm of your application. This ensures that updates written by multiple concurrent workers never results in duplicates.

Additionally Grove has a concept of external_documents. If the content of the source document is synchronized to Grove as an `external_document` (not `document`) and local edits are written to the `document` field Grove ensures that consecutive synchronization operations will not overwrite local edits, while fields that do not have local edits will still be updated from source. An example:

- An event is synchronized from facebook to Grove. The fields are written to the `external_document`, `document` is blank
- An editor determines that the title of the event is unhelpful ("Big Launch!!!") and creates a local edit writing {"title": "Launch of the new Wagner Niebelung Ring Lego Kits!!!"}
- The document now contains the key `title` while the rest of the content is in `external_document`. 
- A client requesting the document will see the merged content of external_document and document
- An updated event is synchronized from facebook. The updated document is written to `external_document`. The body and title of the source document has been updated from the source.
- A client requesting the document sees the updated body, while the title is overridden by the content of document.
- Since the external_document is newer than the document and an updated field is overridden the document is now marked as "conflicted" in grove. An application may provide an interface to the user to resolve this conflict and update the `document`.

## Uid

Across all pebbles grove documents are identified by their uid's. The uid of a grove document always has base class "post". Uids is on the form `<klass>:<canonical path>$<id>`

Typical uids will look like this:

- post.event:apdm.bagera.events.facebook$121
- post.comment:apdm.blogs.firda.fotball.postings.121$453211


# Api

## Create or update document

    POST /posts/:uid # create (omit object id in uid)
    PUT /posts/:uid  # update (must have objecte id in uid)

The uid defines the class and canonical path of the created document. When using PUT an object is must be included in the uid referencing the exact posting to be updated.

The body of the post/put must be the Grove posting in json format and wrapped in a "post"-key. Valid keys in the post:

- `document`: Any valid json hash representing the content of the posting
- `paths`: Any additional paths that you want associated with the posting
- `occurrences`: A hash of arrays of timestamps that you want to attach to the posting. E.g. `occurrences: {"start_time": ["2012-1-1T12:00:00"]}`
- `tags`: An array of tag identifiers. Invalid characters will be stripped.
- `restricted`: A boolean value indicating if this document is private and should only be visible to the user that created it (and gods)
- `external_id`: An id string of the source object for use when synchronizing from external sources. See section "Synchronization from external sources"
- `external_document`: A valid json hash representing the pristine document as seen at the source. For use when synchronizing from eternal sources.

REMEMBER TO WRAP YOUR POSTINGS IN A `post`-NAMESPACE. Like this:

    {"post":{
      "document": {"body": "Hello Grove!"},
      "tags": ["welcome", "tutorial"]}
    }

Command-line example, curling grove for fun and profit:

	curl -XPOST 'http://example.com/api/grove/v1/posts/post.todo:dna.org.a.b' --data '{"session":"session_name","post":{"document": {"body": "Hello Grove!"},"tags": ["welcome", "tutorial"]}}' -H "Content-Type: application/json"

## Delete/reinstate a posting

    DELETE /posts/:uid
    POST /posts/:uid/undelete # Gods only

A posting may be deleted by the original poster or one of the gods of the realm. All deletion in Grove is soft, and a document may be reinstated by a god by invoking the undelete action.

## Retrieval and Queries

    GET /posts/:uid

A specific posting may be retrieved by specifying a full uid to this endpoint. E.g.

    GET /posts/post.event:apdm.bagera.events.facebook$121

A number of specific posts may be retrieved by specifying a comma separated list of uids

    GET /posts/post.event:apdm.bagera.events.facebook$121,post.banan:apdm.bagera$2323

A specific posting may be retrieved by specifying an external_id as uid to this endpoint. E.g.

    GET /posts/myapp_2323

The result is returned as an array in the namespace `posts` in the same order as the posts are specified in the request. If a document could not be found, the result array gets a null entry.

The real meat and potatoes worker action in Grove however is the wildcard posts query. By using wildcards in the uid, collections of posts may be retrieved. Wildcards may be replace parts of the class, path and oid. Examples:

Asterisk:

    *:apdm*$*  # All postings in the apdm realm
    post.comments:apdm.blogs.football.* # All comments in the football blog

Pipe:
    post.comments:apdm.blogs.football|handball.* All comments in the football and handball blog

Caret:
    *:apdm.^blogs.football.comments # Any path starting with apdm and any subset of blogs.football.comments

The full result set of the queries may potentially be huge, so pagination is supported. By default the first 20 results are returned, and the default sort order is `created_at desc`. The sort order can be inverted by adding the parameter `direction=asc`. The pagination parameters is the standard pebbles pagination params:

- `limit`: The desired number of results
- `offset`: The index of the first result returned

The key "pagination" is returned with the result set containing the limit and offset used when requesting the set in addition to the key `last_page` which is true when there are more results to be had.

When using wildcards, additional parameters can be supplied to constrain the results. These are:

- `external_id`: Require that the document has a certain external_id
- `tags`: An comma separated list of tags to require
- `created_by`: An integer specifying a user that should be listed as the creator of the desired document
- `occurrence`: A hash limiting the selection to postings that have a specific occurrence type in a given time window

When limiting for occurrences the following parameters are valid:

- `occurrence[label]`: specifies the kind of occurrence you are looking for, e.g. "start_time"
- `occurrence[from]`: a time stamp. No posting occurring before this time will be returned
- `occurrence[to]`: a time stamp. No posting occurring after this time will be returned
- `occurrence[order]`: either 'asc' or 'desc'. Specifies in what order the postings will be sorted according to the time stamp

