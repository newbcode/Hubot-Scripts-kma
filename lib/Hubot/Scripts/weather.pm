package Hubot::Scripts::weather;

use utf8;
use strict;
use warnings;
use Data::Printer;
use Encode qw(encode decode);
use Text::ASCIITable;
use Text::CharWidth qw( mbswidth );
use List::Compare;
use List::MoreUtils qw(any);

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
    $robot->hear(
        qr/^weather (.+)/i,    
        \&current_process,
    );
}

sub city_process {
    my $msg = shift;

    my $count = 0;
    my $table;
    my $user_input = $msg->match->[0];
    my @input_cities = split (/ /, $user_input );
    my $val_citys = join (' ', values %countris);
    my @val_cities = split (/ /, $val_citys);
    my $lc = List::Compare->new(\@input_cities, \@val_cities);

    my @citynames = $lc->get_intersection;
    my @union_cities = $lc->get_union;

    for my $country ( keys %countris ) {
        for my $cityname ( @citynames ) {
            if ( $countris{$country} =~ /$cityname/ ) {
            $msg->http("http://kma.go.kr/weather/forecast/mid-term_$country.jsp")->get(
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
                        my @am_weathers = $decode_body =~ m{<li title="(.*?)">.*?<li title=".*?">}gsm;
                        my @pm_weathers = $decode_body =~ m{<li title=".*?">.*?<li title="(.*?)">}gsm;

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
                                if ( $country == '02' or $country == '07') {
                                    $table->addRow( $city, @{ $weather{$city}} );
                                    $table->addRow( '  ', @am_weathers );
                                    $table->addRow( '  ', @pm_weathers );
                                }

                                elsif ( any { $cityname eq $_ } qw/춘천 대전 서산 광주 목포 여수 부산 울산 창원/ ) {
                                    $table->addRow( $city, @{ $weather{$city}} );
                                    $table->addRow( '  ', $am_weathers[0], $am_weathers[1],
                                                          $am_weathers[2], $am_weathers[3],
                                                          $am_weathers[4], $am_weathers[5],);
                                    $table->addRow( '  ', $pm_weathers[0], $pm_weathers[1],
                                                          $pm_weathers[2], $pm_weathers[3],
                                                          $pm_weathers[4], $pm_weathers[5],);
                                }
                                elsif ( any { $cityname eq $_ } qw/강릉 청주 전주 대구 안동/ ) {
                                    $table->addRow( $city, @{ $weather{$city}} );
                                    $table->addRow( '  ', $am_weathers[6], $am_weathers[7],
                                                          $am_weathers[8], $am_weathers[9],
                                                          $am_weathers[10], $am_weathers[11],);
                                    $table->addRow( '  ', $pm_weathers[6], $pm_weathers[7],
                                                          $pm_weathers[8], $pm_weathers[9],
                                                          $pm_weathers[10], $pm_weathers[11],);
                                }
                            }
                        }
                        if ($count == scalar (@citynames)) {
                            $msg->send(
                                ("\n", split /\n/, $table)
                            );
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
                $msg->send( $paldos{$paldo}.'-'. '기상전망'.
                    $announcementtime."\n");
                $msg->send( @forecast );
                }
            );
        $caution = 'off';
        }
    }    
    $msg->send($user_input . " 지역은 기상정보가 없습니다.") if $caution eq 'on' ;
}

sub current_process {
    my $msg = shift;

    my $user_input = $msg->match->[0];
    return if $user_input =~ "weekly|forecast|current";
    my @input_cities = split (/ /, $user_input );
    my $last_index = scalar (@input_cities);

    if ( $last_index == 1 ) {
        $msg->http("http://www.kma.go.kr/weather/observation/currentweather.jsp")->get(
        sub {
                my ( $body, $hdr ) = @_;

                return if ( !$body || $hdr->{Status} !~ /^2/ );

                my $decode_body = decode("euc-kr", $body);
                my $announcementtime;
                if ( $decode_body =~ m{<p class="table_topinfo"><.*? alt="기상실황표" />(.*?)</p>} ) {
                    $announcementtime = $1;
                }
                my @cities = $decode_body =~ m{<td><a href=".*?">(.*?)</a></td>}gsm;
                my @status = $decode_body =~ m{<td>(.{1,10})</td>}gsm;

                my $city_cnt = 0;
                my $status_cnt = 11; 
                my $city_check = 'on';
                my @new_status; 

                for my $city ( @cities ) {
                    if ( $user_input eq $city ) {
                        ### status는 날씨의 상태를 가지고 있으며 array slice로 다시 새로운 상태array를 만든다.
                        ### why? *12는 @cities에 들어있는 도시이름이 몇번쨰 index인지 구하고(ex:동두천이면 2번째 인덱스)
                        ### $status + $city_cnt는 @status에 들어있는 총 index를 구한다. 이것은 웹분석을 통해 만들어낸 규칙.   
                        @new_status = @status[ $city_cnt*12 .. $city_cnt*12 + $status_cnt];
                        ### 정보를 받아 오기전에 상태를 waiting로 치환한다.
                        grep { s/&nbsp;/(Waiting)/g } @new_status;

                        $msg->send("$user_input 지역의 현재일기는[$announcementtime] $new_status[0]상태이며 현재기온은 $new_status[4](도), 불쾌지수는 $new_status[6], 일강수는 $new_status[7](mm), 습도는 $new_status[8](%)입니다." );
                        $city_check = 'off';
                        last;
                    }
                $city_cnt++;
                }
            $msg->send("기상제공 지역은 [@cities] 입니다") if $city_check eq 'on';
            $msg->send("\n") if $city_check eq 'on';
            $msg->send("$user_input 지역은 기상정보가 없습니다") if $city_check eq 'on';
            }
        );
    }
    else {
        $msg->send('지역을 2군데 이상입력 하셨습니다');
    }
}

1;

=pod

=head1 Name 

    Hubot::Scripts::weather
 
=head1 SYNOPSIS
 
    weather <city name>  - View current local area weather information. 
    weather weekly <city name> - View weekly local area weather information.
    weather weekly <city name1> <city name2>... - View weekly local areas weather information.
    weather forecast <local name> - View local weather forecast information. (ex: KangWon-Do, Gyeonggi-Do ..)

=head1 AUTHOR

    YunChang Kang <codenewb@gmail.com>
 
=cut
