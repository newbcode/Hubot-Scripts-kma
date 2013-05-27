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
    "02" => "서울 인천 수원 문산",
    "03" => "춘천 강릉",
    "04" => "대전 서산 청주",
    "05" => "광주 목포 여수 전주",
    "06" => "부산 울산 창원 대구 안동",
    "07" => "제주 서귀포",
);

my %paldos = (
    "01" => "전국",
    "02" => "서울 경기도",
    "03" => "강원도",
    "04" => "충청남도 충청북도",
    "05" => "전라남도 전라북도",
    "06" => "경상남도 경상북도",
    "07" => "제주도 제주특별자치도",
);

sub load {
    my ( $class, $robot ) = @_;
 
    $robot->hear(
        qr/^weather weekly (.+)/i,    
        \&city_process,
    );
    $robot->hear(
        qr/^weather forecast (.+)/i,    
        \&fore_process,
    );

}

sub city_process {
    my $msg = shift;

    my $count = 0;
    my $table;
    my $wrong_input;
    my $user_input = $msg->match->[0];
    my @citynames = split (/ /, $user_input );
    #my @country_numbers;
    #pop @cityname unless if ($wrong_input =~ (values %countries) );

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
                        my @am_weathers;
                        my @pm_weathers;
                        while ( $decode_body =~ m{<li title="(.*?)">.*?<li title="(.*?)">}gsm ) {
                            push @am_weathers, "$1";
                            push @pm_weathers, "$2";
                        }

                        my @cities   = $decode_body =~ m{<th scope="row">(.*?)</th>}gsm;
                        my @days     = $decode_body =~ m{<th scope="col"  class="top_line" style=".*?">(.*?)</th>}gsm; 
                        my @temperatures;
                        while ( $decode_body =~ m{<li><span class="col_blue">(\d+)</span> / <span class="col_orange">(\d+)</span></li>}gsm ) {
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
                                headingText => "최저/최고기온(℃ ) 오전/오후 [$announcementtime]",
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
                            elsif ( $cityname eq $city ) {
                                $table->addRow( $city, @{ $weather{$city}} );
                                $table->addRow( '오전', @am_weathers );
                                $table->addRow( '오후', @pm_weathers );
                            }
                        }
                        if ($count == scalar (@citynames)) {
                            $msg->send("\n"), $msg->send($table);
                        }
                    }
                );
            }
        }
    }
}

sub fore_process {
    my $msg = shift;

    my $user_input = $msg->match->[0];

    my $caution = 'on';
    for my $paldo ( keys %paldos ) {
        if ( $paldos{$paldo} =~ /$user_input/ ) {
        $msg->http("http://www.kma.go.kr/weather/forecast/mid-term_$paldo.jsp")->get(
            sub {
                my ( $body, $hdr ) = @_;

                return if ( !$body || $hdr->{Status} !~ /^2/ );

                my $announcementtime = $1;
                my $decode_body = decode("euc-kr", $body);
                if ( $decode_body =~ m{<p class="mid_announcementtime fr">.*?<span>(.*?)</span></p>} ) {
                     $announcementtime = $1;
                }
                my @forecast;
                if ( $decode_body =~ m{<p class="text">(.*?)</p>} ) {
                     my $parser = $1; 
                     @forecast = split (/<br \/>/, $parser);
                }

                my $table = Text::ASCIITable->new({
                utf8        => 0,
                headingText => "기상전망($paldos{$paldo}) - [$announcementtime]",
                cb_count    => sub { mbswidth(shift) },
                });
                $table->setCols($paldos{$paldo});
                for my $cast ( @forecast ) { $table->addRow($cast); }
                $msg->send("\n"), $msg->send($table);
                }
            );
        $caution = 'off';
        }
    }    
    $msg->send($user_input . " 지역은 기상정보가 없습니다.") if $caution eq 'on' ;
}

1;
 
=head1 SYNOPSIS
 
    This is scripts only support korean. 
    weather weekly [country] ... - input country name 
    weather weekly [country1] [country2] [country3] ... - input country name 
    weather forecast [paldo] (ex: kangwon-do or gyeonggi-do) ... - input country name 
 
=cut
