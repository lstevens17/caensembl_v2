=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=head1 MODIFICATIONS

Copyright [2014-2015] University of Edinburgh

All modifications licensed under the Apache License, Version 2.0, as above.

=cut

package EnsEMBL::Web::Document::Element::Copyright;

### Copyright notice for footer (basic version with no logos)

use strict;

sub content {
  my $self = shift;

  my $sd = $self->species_defs;

## BEGIN CAENSEMBL MODIFICATIONS...
my $html = '<div class=lb-ackn-logos>';
$html .= '<a href="http://www.ed.ac.uk"><img title="University of Edinburgh" class="lb-footer-logo" src="/img/edinburgh_logo.png"></a>';
$html .= '</div>';

  return sprintf( qq(
  <div class="column-two left">
		   %s release %s - %s -
		  caenorhabditis.org &copy; <span class="print_hide"><a href="http://www.ed.ac.uk/" style="white-space:nowrap">Edinburgh University</a> / EnsEMBL &copy; <a href="http://www.ebi.ac.uk/" style="white-space:nowrap">EBI</a></span>
      <span class="screen_hide_inline">caenorhabditis.org</span> %s
  </div>),     'caenorhabditis.org", "2", "January 2017", $html
## ...END CAENSEMBL MODIFICATIONS
	       );

}

1;