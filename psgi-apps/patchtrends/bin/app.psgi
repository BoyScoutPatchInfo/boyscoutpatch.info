#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../../lib";
use lib "$FindBin::Bin/../../../../patchtrends-backend/lib";

use patchtrends;

use Plack::Builder;
 
builder {
  mount '/'    => patchtrends->dance;
};
