package patchtrends::Util::eBayRedirects;

# EPN redirect for general eBay'ing
sub to_ebay {
    my ($body_params, $query_params, $route_params) = @_;
    my $redirect_url = q{http://rover.ebay.com/rover/1/711-53200-19255-0/1?icep_ff3=1&pub=5575058914&toolid=10001&campid=5337745539&customid=&ipn=psmain&icep_vectorid=229466&kwid=902099&mtid=824&kw=lg};
    return $redirect_url;
};

# EPN redirect for item number
sub to_ebay_item {
    my ($body_params, $query_params, $route_params) = @_;
    my $itemid = $route_params->{id};
    my $redirect_url = qq{http://rover.ebay.com/rover/1/711-53200-19255-0/1?ff3=4&pub=5575058914&toolid=10001&campid=5337390134&customid=&mpre=http%3A%2F%2Fwww.ebay.com%2Fitm%2F$itemid%2F?nordt=true&orig_cvip=true&rt=nc};
    return $redirect_url;
};

# EPN redirect for seller/store
sub to_ebay_seller {
    my ($body_params, $query_params, $route_params) = @_;
    my $seller = $route_params->{seller};
    my $redirect_url = qq{http://rover.ebay.com/rover/1/711-53200-19255-0/1?ff3=4&pub=5575058914&toolid=10001&campid=5337390134&customid=&mpre=http%3A%2F%2Fwww.ebay.com%2Fusr%2F$seller};
    return $redirect_url;
};

1;

__END__
