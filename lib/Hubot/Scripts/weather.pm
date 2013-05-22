package Hubot::Scripts::weather;

use utf8;
use Data::Dumper;
use Encode qw(encode decode);
use Text::ASCIITable;
use Text::CharWidth qw( mbswidth );

my $local;
my $local_num;
my $announcementtime;
my $city;

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
                    $local_num = $local_p;
                }
            }
            $msg->http("http://www.kma.go.kr/weather/forecast/mid-term_$local_num.jsp")->get(
                sub {
                    my ( $body, $hdr ) = @_;
                    return if ( !$body || $hdr->{Status} !~ /^2/ );
                    my $decode_body = decode("euc-kr", $body);
                    if ( $decode_body =~ m{<p class="mid_announcementtime fr">.*?<span>(.*?)</span></p>} ) {
                        $announcementtime = $1;
                    }

                    my $cnt = 0;
                    my $row_high_temp;
                    my @temp_info;
                    my %weather_hash;

                    my @city_info = $decode_body =~ m{<th scope="row">(.*?)</th>}gsm;
                    my @days_info = $decode_body =~ m{<th scope="col"  class="top_line" style=".*?">(.*?)</th>}mgs;  
                    while ( $decode_body =~ m{<li><span class="col_blue">(\d+)</span> (/) <span class="col_orange">(\d+)</span></li>}mgs ) {
                        $row_high_temp = "$1"."$2"."$3";     
                        push @temp_info, $row_high_temp;
                    }

                    map { $weather_hash{$_} = { $days_info[$cnt] => $temp_info[$cnt++]} } @city_info;
                    print Dumper \%weather_hash;

                    my $table = Text::ASCIITable->new({
                                utf8=>0,
                                headingText => "최저/최고기온(℃ )[$announcementtime]",
                                cb_count    => sub { mbswidth(shift) },
                                });
                    $table->setCols("도시", "$days_info[0]", "$days_info[1]", "$days_info[2]", "$days_info[3]", "$days_info[4]", "$days_info[5]");
                    $table->addRow("$local", "$weather_hash{$days_info[1]}{$temp_info[1]}");
                    $msg->send("\n");
                    $msg->send("$table");
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

