package Hubot::Scripts::weather;

use utf8;
use Data::Printer;
use Encode qw(encode decode);
use Text::ASCIITable;
use Text::CharWidth qw( mbswidth );

my %locals = (
    "01" => "전국",
    "02" => "서울 경기도 인천",
    "03" => "강원도",
    "04" => "충청남도 충청북도",
    "05" => "전라남도 전라북도",
    "06" => "경상남도 경상북도",
    "07" => "제주도 제주특별자치도",
);

sub load {
    my ( $class, $robot ) = @_;
 
    $robot->hear(
        #qr/^local (서울|경기도|인천|강원도|충청남도|충청북도|전라남도|전라북도|경상남도|경상북도|제주도|제주특별자치도)/i,    
        qr/^weather weekly (서울)/i,    
        \&_process,
    );
}

sub _process {
    my $msg = shift;

    my $user_input = $msg->match->[0];
    my $local_num;
    for my $local_p ( keys %locals ) {
        if ( $locals{$local_p} =~ /$user_input/ ) {
            $local_num = $local_p;
        }
    }
    $msg->http("http://www.kma.go.kr/weather/forecast/mid-term_$local_num.jsp")->get(
        sub {
            my ( $body, $hdr ) = @_;

            return if ( !$body || $hdr->{Status} !~ /^2/ );

            my $announcementtime;
            my $decode_body = decode("euc-kr", $body);
            if ( $decode_body =~ m{<p class="mid_announcementtime fr">.*?<span>(.*?)</span></p>} ) {
                $announcementtime = $1;
            }

            #
            # 날씨 정보를 해시화
            # @temperatures 변수를 만든 후 모두 소모함
            #
            my @cities = $decode_body =~ m{<th scope="row">(.*?)</th>}gsm;
            my @days   = $decode_body =~ m{<th scope="col"  class="top_line" style=".*?">(.*?)</th>}gsm; 
            my @temperatures;
            while ( $decode_body =~ m{<li><span class="col_blue">(\d+)</span> / <span class="col_orange">(\d+)</span></li>}gms ) {
                push @temperatures, "$1/$2";
            }

            my %weather;
            for my $city (@cities) {
                for ( 1 .. @days ) {
                    push @{ $weather{$city} ||= [] }, shift(@temperatures);
                }
            }

            #
            # show table
            #
            my $table = Text::ASCIITable->new({
                utf8        => 0,
                headingText => "최저/최고기온(℃ )[$announcementtime]",
                cb_count    => sub { mbswidth(shift) },
            });

            $table->setCols( "도시", @days );
            for my $city (keys %weather) {
                next unless $user_input eq $city;

                $table->addRow( $city, @{ $weather{$city}} );
            }

            $msg->send("\n");
            $msg->send("$table");
        }
    )
    #$msg->send("$local"); 
}

 
1;
 
=head1 SYNOPSIS
 
    weather weekly - kma info 
 
=cut




__DATA__

                            $weather{$city} = [] unless $weather{$city};
                            push @{ $weather{$city} }, shift(@temperatures);

                            $weather{$city} ||= [];
                            push @{ $weather{$city} }, shift(@temperatures);

                            $weather{$city} = $weather{$city} || [];
                            push @{ $weather{$city} }, shift(@temperatures);
