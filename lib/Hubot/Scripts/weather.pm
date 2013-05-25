package Hubot::Scripts::weather;

use utf8;
use Data::Printer;
use Encode qw(encode decode);
use Text::ASCIITable;
use Text::CharWidth qw( mbswidth );

#
# 지역을 해쉬로 담아서 사용
#
my %countris = (
    "01" => "전국",
    "02" => "경기도 서울 인천 수원 문산",
    "03" => "강원도 춘천 강릉",
    "04" => "충청남도 충청북도 대전 서산 청주",
    "05" => "전라남도 전라북도 광주 목포 여수 전주",
    "06" => "경상남도 경상북도 부산 울산 창원 대구 안동",
    "07" => "제주도 제주특별자치도 제주 서귀포",
);

sub load {
    my ( $class, $robot ) = @_;
 
    $robot->hear(
        #qr/^weather weekly (.+)/i,    
        qr/^w (.+)/i,    
        \&city_process,
    );
}

sub city_process {
    my $msg = shift;

    my $count = 0;
    my $table;
    my $user_input = $msg->match->[0];
    my @citynames = split (/ /, $user_input );
    my @country_numbers;

    for my $country ( keys %countris ) {
        for my $cityname ( @citynames ) {
            if ( $countris{$country} =~ /$cityname/ ) {
            $msg->http("http://www.kma.go.kr/weather/forecast/mid-term_$country.jsp")->get(
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
                        #
                        #$weather($city)가 첫번쨰 불릴때는 당연히 FALSE인데 초기값을 
                        #arrayref 넣고 다음부터 참조될때는 arrayref니까 @{}로 보간된 ref를 풀고 push를 함
                        #
                        my %weather;
                        for my $city (@cities) {
                            for ( 1 .. @days ) {
                                push @{ $weather{$city} ||= [] }, shift(@temperatures);
                            }
                        }
                        #
                        # show table
                        #
                        if ( $count == 0 ) {
                                $table = Text::ASCIITable->new({
                                utf8        => 0,
                                headingText => "최저/최고기온(℃ )[$announcementtime]",
                                cb_count    => sub { mbswidth(shift) },
                            });
                        $table->setCols( "도시", @days );
                        }
                        $count++;
                        for my $city (keys %weather) {
                            #next unless $cityname eq $city;
                            if ( $cityname eq '전국' ) {
                                $table->addRow( $city, @{ $weather{$city}} );
                            }
                            elsif ( $cityname eq $city ){
                                $table->addRow( $city, @{ $weather{$city}} );
                            }
                        }
                        if ($count == $#citynames + 1) {
                            $msg->send("\n"), $msg->send($table);
                        }
                    }
                );
            }
        }
    }
}
 
1;
 
=head1 SYNOPSIS
 
    weather weekly country1 country2 ... - input country name 
 
=cut




__DATA__

 $weather{$city} = [] unless $weather{$city};
 push @{ $weather{$city} }, shift(@temperatures);

 $weather{$city} ||= [];
 push @{ $weather{$city} }, shift(@temperatures);

 $weather{$city} = $weather{$city} || [];
 push @{ $weather{$city} }, shift(@temperatures);
