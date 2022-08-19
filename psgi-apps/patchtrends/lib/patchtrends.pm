package patchtrends;

use Dancer2;
use Dancer2::Serializer::JSON ();
use Dancer2::Core::Error      ();
use Dancer2::Core::Response   ();
use DBD::mysql                ();
use Exception::Class          ();

use patchtrends::Search::Active      ();
use patchtrends::Search::Complete    ();
use patchtrends::API::v1::Alerts     ();
use patchtrends::API::v1::Member     ();
use patchtrends::API::v1::ItemBucket ();
use patchtrends::Util::eBayRedirects ();

use patchtrends::Member ();
use patchtrends::Auth   ();
use patchtrends::Bazaar ();
use patchtrends::Email  ();

use POSIX qw/strftime/;

our $VERSION = '1.0';

# white list IPs that will be serving as a proxy in front
# of ptimaged
hook before => sub {
  my $allowed_ips = [qw/127.0.0.1 ::ffff:172.17.0.1/];
  my $ip = request->address // q{};
  if (! grep { /$ip/ } @{$allowed_ips} ) {
    error qq{Unauthorized request from $ip};
    send_error("Internal Server Error", 500);
  }
  return;
};

prefix '/api' => sub {
    get '/search/:searchTerms?' => \&api_search_with_terms;

    # Alerts CRUD
    put  '/alerts/create'              => sub { return _api( q{PUT},    \&patchtrends::API::v1::Alerts::create ) };
    get  '/alerts/read'                => sub { return _api( q{GET},    \&patchtrends::API::v1::Alerts::read_all ) };
    get  '/alerts/read/:id'            => sub { return _api( q{GET},    \&patchtrends::API::v1::Alerts::read ) };
    post '/alerts/update/:id'          => sub { return _api( q{POST},   \&patchtrends::API::v1::Alerts::update ) };
    del  '/alerts/delete/:id'          => sub { return _api( q{DELETE}, \&patchtrends::API::v1::Alerts::delete ) };

    # Member CRUD (just update, lots of room for self servicing API)
    post '/member/update'              => sub { return _api( q{POST}, \&patchtrends::API::v1::Member::update ) };
    post '/member/reset-pw'            => sub { return _api( q{POST}, \&patchtrends::API::v1::Member::reset_password, { q{no-auth} => 1 } ) };

    # Members Functions
    get '/member/authenticated'        => \&api_member_authenticated;

    # Search Endpoints
    get  '/item/details/:id'           => \&api_item_details;
    get  '/mobile/item/:id'            => \&api_mobile_item;
    get  '/bazaar/search/'             => \&api_bazaar_search;
    get  '/mobile/search/:searchTerms' => \&api_mobile_search_terms;
    get  '/bazaar/search/:searchTerms' => \&api_bazaar_search_terms;

    # Collections API
  
    ## ItemBucket Management
    put   '/itembucket'                => sub { return _api( q{PUT},    \&patchtrends::API::v1::ItemBucket::create   ) };  # add new bucket
    get   '/itembucket'                => sub { return _api( q{GET},    \&patchtrends::API::v1::ItemBucket::read_all ) };  # get all buckets 
    get   '/itembucket/:id'            => sub { return _api( q{GET},    \&patchtrends::API::v1::ItemBucket::read     ) };  # read details of bucket with $id;
    patch '/itembucket/:id'            => sub { return _api( q{PATCH},  \&patchtrends::API::v1::ItemBucket::update   ) };  # update details of bucket with $id
    del   '/itembucket/:id'            => sub { return _api( q{DELETE}, \&patchtrends::API::v1::ItemBucket::delete   ) };  # delete bucket with $d

    ## Management of Items in ItemBucket of $id
    get   '/itembucket/:id/items'      => sub { return _api( q{GET},    \&patchtrends::API::v1::ItemBucket::read_items   ) };  # read items in bucket of $id
    put   '/itembucket/:id/items'      => sub { return _api( q{PUT},    \&patchtrends::API::v1::ItemBucket::add_items    ) };  # add items to bucket with $id
    del   '/itembucket/:id/items'      => sub { return _api( q{DELETE}, \&patchtrends::API::v1::ItemBucket::delete_items ) };  # delete specific items, in JSON body
};

prefix '' => sub {

    # public HTML endpoints
    get '/'                            => \&index_page;                           # Differentiates between public index and authenticated index
    get '/reset'                       => \&reset_page;                           # unauthenticated, "password reset" page

    # authenticated HTML endpoints - extract out auth/params/etc like API above
    get  '/alerts'                     => \&alerts_page;                          # manage email alerts
    get  '/bazaar'                     => \&active_items_page;                    # active for sale on eBay
    get  '/item/details/:id'           => \&item_details_page;                    # item details page
    get  '/saved-items'                => \&item_buckets_page;                    # manage lists for saved items (ItemBuckets)
    get  '/saved-items/view/:id'       => \&item_buckets_items_page;              # manage items in a specific saved list
    get  '/logout'                     => \&logout_and_redirect_to_index;         # logout
    post '/payment'                    => \&handle_payment;                       # (in progress) - handle PayPal IPN
    get  '/payment'                    => \&handle_payment;                       # (in progress) - handle PayPal IPN
    get  '/search'                     => \&search_page;                          # main search page for members
    get  '/settings'                   => \&settings_page;                        # password update page 

    # Login form processing action endpoint
    #get  '/login'                      => \&authenticate_and_redirect_to_index;   # process login
    post '/login'                      => \&POST_authenticate_and_redirect_to_index;

    # eBay redirect handlers
    get '/ebay/s/:seller'              => sub { _redirect( \&patchtrends::Util::eBayRedirects::to_ebay_seller ) };
    get '/ebay'                        => sub { _redirect( \&patchtrends::Util::eBayRedirects::to_ebay ) };
    get '/ebay/:id'                    => sub { _redirect( \&patchtrends::Util::eBayRedirects::to_ebay_item ) };

    # testing endpoints
    get '/check' => sub {

        # for haproxy check
        patchtrends::_set_api_response_headers(q{GET});
        return 1;
    };

    get '/debug/env' => sub {
        patchtrends::_set_api_response_headers(q{GET});
        return 'fur';
    };

    get '/debug/request' => sub {
        patchtrends::_set_api_response_headers(q{GET});
        return Data::Dumper::Dumper(request);
    };
};

# API handler caller wrapper - aware of Exception::Class exceptions
sub _api {
    my ( $method, $code_ref, $opts_ref ) = @_;
    _set_api_response_headers($method, q{application/json});

    my $dbh = _dbh(q{userdatabase});

    local $@;
    my %body  = params(q{body});
    my %query = params(q{query});
    my %route = params(q{route});

    my $member_info = _api_auth_init($opts_ref);
    bless $member_info, q{patchtrends::Member} if $member_info and ref $member_info ne q{patchtrends::Member};

    my $result = eval { $code_ref->( $dbh, config(), $member_info, \%body, \%query, \%route ) } || undef;

    # disconnect DB first
    $dbh->disconnect();

    # then look for exceptions to process
    if ( not $result and defined $@ ) {
        my $error = _process_api_exceptions($@);
        status $error->{status};
    }
    send_as JSON => $result;
}

sub _redirect {
    my $code_ref = shift;
    redirect $code_ref->( body_parameters()->as_hashref, query_parameters()->as_hashref, route_parameters()->as_hashref );
    return;
}

sub _set_api_response_headers {
    my ( $method, $content_type ) = shift;    #GET, POST, etc
    header 'Server'          => 'beep boop';
    header 'X-Frame-Options' => 'DENY';
    header 'Server'          => 'nginx';

    #header 'Content-Security-Policy' => "default-src dev.boyscoutpatch.info www.boyscoutpatch.info boyscoutpatch.info";
    header 'Access-Control-Allow-Credentials' => 'true';
    header 'Access-Control-Allow-Methods'     => $method;
    header 'Access-Control-Allow-Origin'      => '*';
    header 'X-XSS-Protection'                 => "1; mode=block";
    header 'X-Content-Type-Options'           => 'nosniff';
    header 'Referrer-Policy'                  => 'no-referrer';
    return;
}

# Will result in a proper 'application/json' 403 if not authenticated
sub _api_auth_init {
    my $opts_ref = shift;
    return undef if $opts_ref->{q{no-auth}};
    my $member_info = session 'member_info';
    if (not $member_info) {
        $member_info = bless q{patchtrends::Member}, $member_info;
    }
    elsif ( not $member_info ) {
        my $app = app();
        my $err = Dancer2::Core::Error->new(
            content  => q/{"message":"unauthorized"}/,
            response => response(),
            app      => $app,
        )->throw;

        # Immediately return to dispatch if with_return coderef exists
        $app->has_with_return && $app->with_return->($err);
        return $err;
    }
    return $member_info;
}

# Search API Handlers

sub api_search_with_terms {
    my $member_info = _assert_auth_init();
    patchtrends::_set_api_response_headers(q{GET});
    my $s           = patchtrends::Search::Complete->new;
    my $terms       = param('searchTerms') // q{};
    # fields to tell sphinx to return (cuts down on unnecessary network traffic)
    # Note: the default "doc" field is the same as "itemid" so don't send it
    my $fields_ref  = [qw/bestoffer endtime starttime endtime primarycategory store currentprice seller title bidcount buyitnow itemsold postalcode listingtype/];

    my $results     = $s->search(
        sphinx => config->{sphinx}->{completed},
        terms  => $terms,
        query  => request->query_parameters(),
	fields => $fields_ref,
    );

    my $dbh = _dbh(q{userdatabase});
    my $ok = _log_search( $member_info, $terms, $dbh );

    $dbh->disconnect;
    send_as JSON => $results;
}

# Member (service) API Handlers

# returns JSON, '{"username":"$username"}' if authenticated;
#  _api_auth_init throws a 403 if not
sub api_member_authenticated {
    patchtrends::_set_api_response_headers(q{GET});
    my $member_info = _api_auth_init();
    my $response = { username => $member_info->username };
    send_as JSON => $response;
}

# handle patchbazaar queries
sub api_bazaar_search {
    my $member_info = _assert_auth_init();
    patchtrends::_set_api_response_headers(q{GET});
    my $s       = patchtrends::Search::Active->new;
    my $q       = request->query_parameters();
    my $results = $s->search(
        sphinx => config->{sphinx}->{active},
        terms  => q{ },
        query  => $q->as_hashref,
    );

    send_as JSON => $results;
}

sub api_bazaar_search_terms {
    my $member_info = _assert_auth_init();
    patchtrends::_set_api_response_headers(q{GET});
    my $s       = patchtrends::Search::Active->new;
    my $q       = request->query_parameters();
    my $terms   = ( param('searchTerms') ) ? param('searchTerms') : q{ };
    my $results = $s->search(
        sphinx => config->{sphinx}->{active},
        terms  => $terms,
        query  => $q->as_hashref,
    );
    send_as JSON => $results;
}

# Payment Hander
#
# ability to cancel account (no refund)

# WORK IN PROGRESS
sub handle_payment {
return q{};
  require Data::Dumper;
  require HTTP::Tiny;
  open my $fh, q{>}, q{/home/patchtrends/dump.out};
 # print $fh Data::Dumper::Dumper(request->body, request->headers->flatten());
  # 1. receive request
    # 2. respond to PP with a request for verification

    # 3. get verification back, proceed with adding/updating member's record
    my $req = HTTP::Tiny->new();
    $req->{content} = request->body . q{&cmd=_notify-validate};
    $req->{headers}->{'content-type'} = "application/x-www-form-urlencoded";
 #   print $fh Data::Dumper::Dumper($req);
 local $@;
 eval {
    my $resp = $req->request(q{POST}, q{https://ipnpb.sandbox.paypal.com/cgi-bin/webscr});
    print $fh Data::Dumper::Dumper($resp);
  };
    print $fh Data::Dumper::Dumper($@) if $@;

    # Assuming verification...
    # 1. insert IPN record
    # 2. create/update member
    # 3. send email
    my $iSQL  = q{INSERT INTO tbl_pp_ipn_log (txn_id, txn_parent_id, raw, txn_type, payer_id, subscr_id, received_date) VALUE (?,?,?,?,?,?,now())};
return q{};
}

# Content Handlers

sub _assert_auth_init {
    my $member_info = session 'member_info';
    redirect '/' unless $member_info;
    return $member_info;
}

sub index_page {
    patchtrends::_set_api_response_headers(q{GET});
    my $member_info = session 'member_info';
    if ( not $member_info ) {
        send_as html => template 'index', {}, { layout => undef };
    }
    else {
        send_as html => template 'member-home', { member_info => $member_info, slack_invite_link => config->{slack}->{invite_link} };
    }
}

sub reset_page {
    patchtrends::_set_api_response_headers(q{GET});
    my $member_info = session 'member_info';
    redirect '/settings' if defined $member_info;
    send_as html => template 'reset-password', {}, { layout => undef };
}

sub alerts_page {
    patchtrends::_set_api_response_headers(q{GET});
    my $member_info = _assert_auth_init;
    send_as html => template 'alerts', { member_info  => $member_info, slack_invite_link => config->{slack}->{invite_link} };
}

sub item_buckets_page {
    patchtrends::_set_api_response_headers(q{GET});
    my $member_info = _assert_auth_init;
    send_as html => template 'item-buckets-manage-lists.tt', { member_info => $member_info, slack_invite_link => config->{slack}->{invite_link} };
}

sub item_buckets_items_page {
    patchtrends::_set_api_response_headers(q{GET});
    my $member_info = _assert_auth_init;
    bless $member_info, q{patchtrends::Member};
    my $bucket_id = route_parameters->get('id');
    my $dbh = _dbh(q{userdatabase});
    my $sSQL = q{SELECT name, visibility, url_key FROM tbl_item_buckets WHERE bucket_id=? AND fk_owner_id=? AND archived IS NULL}; 
    my $list_details =$dbh->selectrow_hashref($sSQL, undef, $bucket_id, $member_info->id); 
    $dbh->disconnect;

    # send 404 if not found or more than 1 list is found for some reason
    #@send_error("Not Found", 404) if not @$list_details or @$list_details > 1;

    # assumes success
    send_as html => template 'item-buckets-manage-list-items.tt', { member_info => $member_info, bucket_id => $bucket_id, list_details => $list_details };
}

sub settings_page {
    patchtrends::_set_api_response_headers(q{GET});
    my $member_info = _assert_auth_init;
    send_as html => template 'settings.tt', { member_info => $member_info, slack_invite_link => config->{slack}->{invite_link} };
}

sub search_page {
    patchtrends::_set_api_response_headers(q{GET});
    my $member_info = _assert_auth_init;
    send_as html => template 'simple-search', { member_info => $member_info, slack_invite_link => config->{slack}->{invite_link} };
}

sub logout_and_redirect_to_index {
    patchtrends::_set_api_response_headers(q{GET});
    app->destroy_session;
    redirect '/';
}

sub authenticate_and_redirect_to_index {
    patchtrends::_set_api_response_headers(q{GET});
    my $member_info = _assert_auth_init;
    my $next_uri    = '/';

    if ( defined $member_info ) {
        $next_uri = '/search';
    }

    redirect $next_uri;
}

sub POST_authenticate_and_redirect_to_index {
    patchtrends::_set_api_response_headers(q{POST});
    my $username = body_parameters->get('username'); #param('username');
    my $password = body_parameters->get('password'); #param('password');

    my $next_uri = '/';

    if ( my $member_info = _authenticate( $username, $password ) ) {
        session 'member_info' => $member_info;
        $next_uri = '/search';
    }

    redirect $next_uri;
}

# patchbazaar.com HTTP
sub active_items_page {
    my $member_info = _assert_auth_init();
    patchtrends::_set_api_response_headers(q{GET});
    send_as html => template 'bazaar', { member => $member_info }, { layout => undef };
}

sub api_item_details {
    my $member_info = _assert_auth_init;
    patchtrends::_set_api_response_headers(q{GET});
    my $itemid = param('id');
    my $a      = patchtrends::Search::Active->new;
    my $c      = patchtrends::Search::Complete->new;
    my $q      = request->query_parameters();
    my ( $details, $is_active );

    $details = $c->item_details(
        sphinx => config->{sphinx}->{completed},
        query  => { itemid => $itemid },
    );

    # if not, get active details, mark as active
    if ( !$details ) {
        $details = $a->item_details(
            sphinx => config->{sphinx}->{active},
            query  => { itemid => $itemid },
        );
        $is_active++ if $details;
    }
    $details->{is_active} = $is_active;
    return $details;
}

sub item_details_page {
    my $member_info = _assert_auth_init;
    patchtrends::_set_api_response_headers(q{GET});
    my $itemid      = param('id');
    my $a           = patchtrends::Search::Active->new;
    my $c           = patchtrends::Search::Complete->new;
    my $q           = request->query_parameters();

    my ( $details, $is_active );

    $details = $c->item_details(
        sphinx => config->{sphinx}->{completed},
        query  => { itemid => $itemid },
    );

    # if not, get active details, mark as active
    if ( !$details ) {
        $details = $a->item_details(
            sphinx => config->{sphinx}->{active},
            query  => { itemid => $itemid },
        );
        $is_active++ if $details;
    }

    # Get similar completed items
    my $similar_completed = $c->similar_items(
        sphinx => config->{sphinx}->{completed},
        query  => { label => $details->{title} },
    );

    # Get similar active items
    my $similar_active = $c->similar_items(
        sphinx => config->{sphinx}->{active},
        query  => { label => $details->{title} },
    );

    # Check bid history
    my $history = [];

    local $@;
    my $base_image_url = q{https://images.boyscoutpatch.info/item/image};
    my $image_ref      = eval {
        my $url      = qq{$base_image_url/$itemid/files};
        my $response = HTTP::Tiny->new->get($url);
        return from_json( $response->{content} );
    } || {};
    $image_ref->{base_image_url} = $base_image_url;

    if ($is_active) {

        # compute time left (seconds)
        my $now = time();
        $details->{'seconds_left'} = int $details->{'endtimeunix'} - $now;
        $details->{'minutes_left'} = sprintf( "%0.2f", $details->{'seconds_left'} / 60 );
        $details->{'hours_left'}   = sprintf( "%0.2f", $details->{'minutes_left'} / 60 );
        $details->{'days_left'}    = sprintf( "%0.2f", $details->{'hours_left'} / 24 );
        send_as html => template 'bazaar-details-active', { image_ref => $image_ref, item => $details, member => $member_info, similar_completed => $similar_completed, similar_active => $similar_active, history => $history }, { layout => undef };
    }
    else {
        send_as html => template 'bazaar-details-completed', { image_ref => $image_ref, item => $details, member => $member_info, similar_completed => $similar_completed, similar_active => $similar_active, history => $history }, { layout => undef };
    }
}

# HELPERS

# manage converting X::* exceptions to HTTP statuses
sub _e_to_status {
    my $e_type = shift;

    my $status = {
	q{X::BadRequest}           => 400,
        q{FailedAuthentication}    => 403,
        q{X::FailedAuthentication} => 403,
        q{X::RecordNotFound}       => 404,
        q{X::InvalidParameter}     => 422,
        q{X::DB::Error}            => 503,
        default                    => 503,
    };

    return $status->{$e_type} // $status->{default};
}

sub _process_api_exceptions {
    my $e      = shift;
    my $status = _e_to_status( ref $e );
    my $error  = {
        message => $e->message,
        status  => $status,
    };
    return $error;
}

sub _authenticate {
    my ( $username, $password ) = @_;
    my $dbh = _dbh(q{userdatabase});
    my $auth = patchtrends::Auth->new( dbh => $dbh );

    my $member = undef;

    my $userid = $auth->get_userid( $username, $password );
    if ($userid) {
        $member = patchtrends::Member->new( { id => $userid } );
        $member->load($dbh);
        my $ok = _log_request( $member, $dbh );

        # do not allow authentication if access log can't be written
        if ( not $ok ) {
            $member = undef;
            app->destroy_session;
        }
    }
    $dbh->disconnect;
    return $member;
}

sub _log_search {
    my $member = shift;
    my $terms  = shift;
    my $dbh    = shift;
    my $env    = request->env;

    # log attempt
    my $ip = ( $env->{HTTP_X_FORWARDED_FOR} ) ? $env->{HTTP_X_FORWARDED_FOR} : $env->{REMOTE_ADDR};
    my $iSQL = q{INSERT INTO tbl_search_log (terms, fk_user_id, env, cgi, server_addr, session_id, sign_in_email, otp_token, date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, now())};

    # Note: $member->username, $member->email, $member->id, session->id
    my $log = eval {
        $dbh->do( $iSQL, undef, $terms, $member->id, Data::Dumper::Dumper($env), Data::Dumper::Dumper(request), $ip, session->id, $member->email, undef );
        $dbh->commit();
    } or undef;
    return $log;
}

sub _log_request {
    my $member = shift;
    my $dbh    = shift;
    my $env    = request->env;

    # log attempt
    my $ip   = ( $env->{HTTP_X_FORWARDED_FOR} ) ? $env->{HTTP_X_FORWARDED_FOR} : $env->{REMOTE_ADDR};
    my $iSQL = q{INSERT INTO tbl_access_log (username, sign_in_email, authenticated, fk_user_id, remote_addr, session_id, attempt_date) VALUES (?, ?, ?, ?, ?, ?, now())};
    my $log  = eval {
        $dbh->do( $iSQL, undef, $member->username, $member->email, 1, $member->id, $ip, session->id );
        $dbh->commit();
    } or undef;
    return $log;
}

sub _dbh {
    my $database = shift;

    # DB connection params
    my $host       = config->{plugins}->{Database}->{connections}->{$database}->{host};
    my $port       = config->{plugins}->{Database}->{connections}->{$database}->{port};
    my $db         = config->{plugins}->{Database}->{connections}->{$database}->{database};
    my $user       = config->{plugins}->{Database}->{connections}->{$database}->{username};
    my $pw         = config->{plugins}->{Database}->{connections}->{$database}->{password};
    my $params_ref = { RaiseError => 1, AutoCommit => 0 };

    my $dbh = DBI->connect( "DBI:mysql:$db:$host:$port", $user, $pw, $params_ref );
    return $dbh;
}
1;

__END__
