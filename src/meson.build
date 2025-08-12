# Configure DEFAULT_PAGESIZE via config.h
confdata = configuration_data()
page_size = get_option('page_size')
if page_size != 'auto'
  confdata.set_quoted('DEFAULT_PAGESIZE', page_size)
else
  # For "auto", leave it undefined so runtime detection happens
endif

config_h = configure_file(output : 'config.h', configuration : confdata)

executable(
  'patchelf',
  [ 'patchelf.cc', 'patchelf.h', config_h ],
  include_directories : include_directories('.'),
  cpp_args : [ '-include', meson.current_build_dir() / 'config.h' ],
  install : true,
)
