#This example updates the device(s) realm based on the settings for ip domain name 
#https://bna.local/bca-networks/services/DeviceService?wsdl
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;
use warnings;
use Getopt::Long;
use LWP::UserAgent;
use HTTP::Request::Common;

my $out_fh;
my $userAgent = LWP::UserAgent->new(agent => 'perl post');
my $usrToken;
my $deviceKey;
my $deviceGuid;
my $deviceCategory;
my $config_fh;
my $accessMode;
my $address;
my $transferMode;

#Get Arguments (-f Config file; -d Device Name; -s Config Search String; -r Realm to Update; -t (Optional) trace file
my %args;
GetOptions(\%args,
           "f=s",
		   "d=s",
		   "s=s",
		   "r=s",
		   "t=s",
) or die "Invalid arguments!";
die "Missing Config File -f!" unless $args{f};
die "Missing Device Name -d!" unless $args{d};
die "Missing Search String -s!" unless $args{s};
die "Missing Realm -r!" unless $args{r};


if ($args{t}) {
  open $out_fh, ">>trace.txt" or die "Could not open trace file";
  print $out_fh "+++++++" . scalar localtime . "+++++++++\n";
}


if ($args{t}) {
	print $out_fh "Processing Config File  -> " . $args{f} . " For Device -> " . $args{d} . " Realm -> " . $args{r} . "\n";
}


open($config_fh, "<$args{f}");

#process configuration file against search string
while (<$config_fh>) 
{

	my($line) = $_;
	chomp($line);
	if ($line =~ /$args{s}/i) {
		
		if ($args{t}) {
			print $out_fh "BINGO Match  ->" . $line . " With ->" . $args{s} . "\n";
		}
		
		#if match is found then update the devices realm
		getUsrToken();
		deviceDetails();
		updateRealm();
		
	}


}


close($config_fh);

if ($args{t}) {
	close($out_fh);
}






sub getUsrToken {

#Reduce overhead for subsequent API calls.  Based on how script is called this may not even be necessary.
if ($usrToken) {
	return;
}

my $login = '<soapenv:Envelope 
xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
xmlns:ser="http://service.ws.bcan.bmc.com">
   <soapenv:Header/>
   <soapenv:Body>
      <ser:doLogin>
         <!--Optional:-->
         <ser:username>sysadmin</ser:username>
         <!--Optional:-->
         <ser:password>bmcAdm1n</ser:password>
      </ser:doLogin>
   </soapenv:Body>
</soapenv:Envelope>';



my $response = $userAgent->request(POST 'https://bna.local/bca-networks/services/AuthenticationService.AuthenticationServiceHttpsSoap11Endpoint',Content_Type => 'text/xml', Content => $login);


if ($args{t}) {
  print $out_fh "Authentication Response ->\n ";
  print $out_fh $response->as_string . "\n";
}

		my($line) = $response->as_string;

		
		chomp($line);
		
		if ($line =~ /<ns:return/i) {
			
			($usrToken) = $line =~ /<ns:return>(.*?)<\/ns:return>/;
			
			if ($args{t}) {
				print $out_fh "User Token -> " . $usrToken . "\n";
			}			
		}

}


sub updateRealm {
#Update devices realm.  This method is only called if the configuration matches the search string.  In this example we are setting the Device Security Profile to default.
#You will need to take into consideration any Device Security Profiles in use.

my $message = '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ser="http://service.ws.bcan.bmc.com" xmlns:xsd="http://dto.bcan.bmc.com/xsd">
   <soapenv:Header/>
   <soapenv:Body>
      <ser:modifyDevice>
         <ser:userToken>'.$usrToken.'</ser:userToken>
         <ser:deviceDto>
            <xsd:name>'.$args{d}.'</xsd:name>
			 <xsd:key>
               <xsd:keyString>'.$deviceKey.'</xsd:keyString>
            </xsd:key>
			<xsd:deviceTypeGuid>'.$deviceGuid.'</xsd:deviceTypeGuid>
			<xsd:category>'.$deviceCategory.'</xsd:category>
            <xsd:realm>
               <xsd:name>'.$args{r}.'</xsd:name>
            </xsd:realm>
			<xsd:primaryInterface>
				<xsd:deviceSecurityProfileName>Default</xsd:deviceSecurityProfileName>
				<xsd:accessMode>'.$accessMode.'</xsd:accessMode>
                <xsd:address>'.$address.'</xsd:address>
				<xsd:transferMode>'.$transferMode.'</xsd:transferMode>
			</xsd:primaryInterface>
         </ser:deviceDto>
      </ser:modifyDevice>
   </soapenv:Body>
</soapenv:Envelope>';



my $response = $userAgent->request(POST 'https://bna.local/bca-networks/services/DeviceService.DeviceServiceHttpSoap12Endpoint/', Content_Type => 'text/xml', Content => $message);

if ($args{t}) {
  print $out_fh "Update Realm Response ->\n ";
  print $out_fh $response->as_string . "\n";
  
}

}

sub deviceDetails {
#Retrieve details necessary for updating device.

my $message = '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ser="http://service.ws.bcan.bmc.com" xmlns:xsd="http://dto.bcan.bmc.com/xsd">
   <soapenv:Header/>
   <soapenv:Body>
      <ser:getDevices>
         <ser:userToken>'.$usrToken.'</ser:userToken>
         <ser:deviceFilter>
            <xsd:nameMatch>'.$args{d}.'</xsd:nameMatch>
         </ser:deviceFilter>
      </ser:getDevices>
   </soapenv:Body>
</soapenv:Envelope>';

my $response = $userAgent->request(POST 'https://bna.local/bca-networks/services/DeviceService.DeviceServiceHttpSoap12Endpoint/', Content_Type => 'text/xml', Content => $message);

if ($args{t}) {
  print $out_fh "Get Device Response ->\n ";
  print $out_fh $response->as_string . "\n";
}

	my($line) = $response->as_string;
	chomp($line);		
		#print $line . "\n";
		if ($line =~ /<ax25:keyString>/i) {
			
			($deviceKey) = $line =~ /<ax25:keyString>(.*?)<\/ax25:keyString>/;

			if ($args{t}) {
				print $out_fh "Device Key ->" . $deviceKey . "\n";
			}
			
		}
		
		if ($line =~ /<ax25:deviceTypeGuid>/i) {
			
			($deviceGuid) = $line =~ /<ax25:deviceTypeGuid>(.*?)<\/ax25:deviceTypeGuid>/;
			
			if ($args{t}) {
				print $out_fh "Device GUID ->" . $deviceGuid . "\n";
			}			
			
			
		}
		
		if ($line =~ /<ax25:category>/i) {
			
			($deviceCategory) = $line =~ /<ax25:category>(.*?)<\/ax25:category>/;

			if ($args{t}) {
				print $out_fh "Device Category->" . $deviceCategory . "\n";
			}
			
			
		}

		#If the realm you are updating to is not in the Devices Security Profile then you may need to modify the security profile of the device 
		
		if ($line =~ /<ax25:accessMode>/i) {
			
			($accessMode) = $line =~ /<ax25:accessMode>(.*?)<\/ax25:accessMode>/;

			if ($args{t}) {
				print $out_fh "Access Mode -> " . $accessMode . "\n";
			}

		}
		
		if ($line =~ /<ax25:address>/i) {
			
			($address) = $line =~ /<ax25:address>(.*?)<\/ax25:address>/;

			if ($args{t}) {
				print $out_fh "Address  -> " . $address . "\n";
			}

		}
		
		if ($line =~ /<ax25:transferMode>/i) {
			
			($transferMode) = $line =~ /<ax25:transferMode>(.*?)<\/ax25:transferMode>/;

			if ($args{t}) {
				print $out_fh "Transfer Mode  -> " . $transferMode . "\n";
			}

		}
		
		


}
