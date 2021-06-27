# Zanzibar PG

This is a proof of concept implementation of the [Zanzibar](https://research.google/pubs/pub48190/) ACL language in pure PL/pgSQL.

The goal is only to replicate the relation tuple resolution API.

Much of Zanzibar's special features are actually implementation details of the distributed caching and consistency model which this project makes not attempt to replicate.

My motivation for creating this was to ensure I fully understand how the resolution works when using naive depth first search and explore how simply it can be done if you don't need a globally available version of this for smaller projects that still have complex authorization needs.

## Functions

### Expand
Expand allows users to compute the list of subjects that satisfy a relation on an object.
```sql
SELECT zanzibar_expand('view', 'videos', '/cats/1.mp4');
```

### Check
Check is used to check if a specific subject has a relation on a object either directly or via any subject sets.
```sql
SELECT zanzibar_check('*', 'view', 'videos', '/cats/1.mp4');
```

### Enumerate
Not part of the Zanzibar API. This performs the reverse lookup of expand and finds all resources a subject has access to in a given namespace.
```sql
SELECT zanzibar_enumerate('cat lady', 'view', 'videos');
```

## Limitations

No subject-set rewrites meaning that all tuples to be evaluated need to be materialised.

## Related projects/services

* [Ory Keto](https://www.ory.sh/keto/) - An open-source Go implemenation of Zanzibar.
* [access-controller](https://github.com/authorizer-tech/access-controller) - Another Go implementation of Zanzibar, seems further along than Keto w.r.t distributed operation in particular.
* [authzed](https://authzed.com/) - SaaS that implements the Zanzibar API with slight tweaks for better multi-tenancy.
