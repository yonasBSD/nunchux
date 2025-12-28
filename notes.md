# nunchux notes

- Cache and just/npm plugins: I think it could be nice with a caching
invalidaotr that is the direcotry that the user is in. currently when in ~/a it
may show just files there. When the user moves to ~/b those just recipes still
show because they are cached. When the menu refreshes in ~/b the items will
dissapear. Maybe we could know this already in the cache and say that just
recipes (and npm scripts) are only valid for the directory where they were found.

