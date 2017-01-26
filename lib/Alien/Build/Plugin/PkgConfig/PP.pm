package Alien::Build::Plugin::PkgConfig::PP;

use strict;
use warnings;
use Alien::Build::Plugin;
use Carp ();
use Env qw( @PKG_CONFIG_PATH );

# ABSTRACT: Probe system and determine library or tool properties using PkgConfig.pm
# VERSION

has '+pkg_name' => sub {
  Carp::croak "pkg_name is a required property";
};

has minimum_version => undef;

sub _cleanup
{
  my($value) = @_;
  $value =~ s{\s*$}{ };
  $value;
}

sub init
{
  my($self, $meta) = @_;
  
  $meta->add_requires('configure' => 'PkgConfig' => '0.14026');

  $meta->register_hook(
    probe => sub {
      my $pkg = PkgConfig->find($self->pkg_name);
      return 'share' if $pkg->errmsg;
      if(defined $self->minimum_version)
      {
        my $version = PkgConfig::Version->new($pkg->pkg_version);
        my $need    = PkgConfig::Version->new($self->minimum_version);
        if($version < $need)
        {
          return 'share';
        }
      }
      'system';
    },
  );

  my $gather = sub {
    my($build) = @_;
    my $pkg = PkgConfig->find($self->pkg_name, search_path => [@PKG_CONFIG_PATH]);
    die "second load of PkgConfig.pm @{[ $self->pkg_name ]} failed: @{[ $pkg->errmsg ]}"
      if $pkg->errmsg;
    $build->runtime_prop->{cflags}  = _cleanup scalar $pkg->get_cflags;
    $build->runtime_prop->{libs}    = _cleanup scalar $pkg->get_ldflags;
    $build->runtime_prop->{version} = $pkg->pkg_version;
    $pkg = PkgConfig->find($self->pkg_name, static => 1, search_path => [@PKG_CONFIG_PATH]);
    $build->runtime_prop->{cflags_static} = _cleanup scalar $pkg->get_cflags;
    $build->runtime_prop->{libs_static}   = _cleanup scalar $pkg->get_ldflags;
  };
  
  $meta->register_hook(
    gather_system => $gather,
  );

  $meta->register_hook(
    gather_share => $gather,
  );
  
  $self;
}

1;
