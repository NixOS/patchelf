project(
  'patchelf',
  'cpp',
  'c',
  version : files('version'),
  default_options : {
    'cpp_std' : 'c++17',
    'warning_level' : '2',
  },
  meson_version : '>=1.2',
)

subdir('src')
#subdir('tests') # TODO

install_man('patchelf.1')

#specfile = configure_file(
#  output : 'patchelf.spec',
#  configuration : {'PACKAGE_VERSION' : meson.project_version()},
#)

# Commented things out should only be for `meson dist`. Need to
# reimplement for that.
install_data(
  'README.md',
  #'COPYING',
  #specfile,
  #'version',
  install_dir : get_option('datadir') / 'doc' / 'patchelf',
)
