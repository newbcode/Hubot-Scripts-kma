package Hubot::Scripts::weather;
use utf8;
use Encode qw(encode decode);
use Text::ASCIITable;

my $local;
my $local_num;
my %locals = (
    "01" => "전국",
    "02" => "서울 경기도 인천",
    "03" => "강원도",
    "04" => "충청남도 충청북도",
    "05" => "전라남도 전라북도",
    "06" => "경상남도 경상북도",
    "07" => "제주도 제주특별자치도",
);
my $announcementtime;

sub load {
    my ( $class, $robot ) = @_;
 
    ## robot respond only called its name first. `hubot xxx`
    $robot->respond(
        qr/hi/i,                 # aanoaa> hubot: hi
        sub {
            my $msg = shift;     # Hubot::Response
            $msg->reply('hi');   # hubot> aanoaa: hi
        }
    );
 
    $robot->hear(
        qr/(hello)/i,    # aanoaa> hello
                         # () 안에 있는건 capture 됨
                         # $msg->match->[0] eq 'hello'
        sub {
            my $msg = shift;
            $msg->send('hello');  # hubot> hello
        }
    );
    $robot->hear(
        #qr/^local (서울|경기도|인천|강원도|충청남도|충청북도|전라남도|전라북도|경상남도|경상북도|제주도|제주특별자치도)/i,    
        qr/^weather weekly (서울)/i,    
        sub {
            my $msg = shift;
            $local = $msg->match->[0];
            foreach my $local_p ( keys(%locals) ) {
                if ( $locals{$local_p} =~ /$local/ ) {
                    #$msg->send("matched $local");
                    $local_num = $local_p;
                }
            }
            $msg->http("http://www.kma.go.kr/weather/forecast/mid-term_$local_num.jsp")->get(
                sub {
                    my %temp;
                    my ( $body, $hdr ) = @_;
                    return if ( !$body || $hdr->{Status} !~ /^2/ );
                    my $decode_body = decode("euc-kr", $body);
                    if ( $decode_body =~ m{<p class="mid_announcementtime fr">.*?<span>(.*?)</span></p>} ) {
                        my $announcementtime = $1;
                        $msg->send("$announcementtime");
                    }
                    if ( $decode_body =~ m{<th scope="row">(.+)</th>} ) {
                        my $city = $1;
                        my @weather_info;
                        if ( $city eq $local ) {
                            push @weather_info, $local;
                            $msg->send("matched $city");
                        }
                    }
                    my $table = Text::ASCIITable->new({
                                headingText => "최저/최고기온 $announcementtime",
                                });
                    $table->setCols(qw/ 도시  /);
                }
            )
            #$msg->send("$local"); 
        }
    );
}
 
1;
 
=head1 SYNOPSIS
 
    hello - say hello
    hubot hi - say hi to sender
 
=cut

