# nunchux notes

- Cache and just/npm plugins: I think it could be nice with a caching
invalidaotr that is the direcotry that the user is in. currently when in ~/a it
may show just files there. When the user moves to ~/b those just recipes still
show because they are cached. When the menu refreshes in ~/b the items will
dissapear. Maybe we could know this already in the cache and say that just
recipes (and npm scripts) are only valid for the directory where they were found.

- Icons for task runners: It would be nice if each plugin can define an icon for
  their items. The user should be able to override these with config settings.
It could be nice to have a way to check if the user is using a nerdfont, and
then have one icon from a nerdfont, and a fallback if they don't user a
nerdfont. Not sure exactly how to do this though.
