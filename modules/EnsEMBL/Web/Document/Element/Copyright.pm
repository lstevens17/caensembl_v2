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
#$html .= '<a href="https://www.keio.ac.jp"><img title="Keio University" class="lb-footer-logo" src="/img/keio_logo.png"></a>';
$html .= '<a href="http://www.ed.ac.uk"><img title="University of Edinburgh" class="lb-footer-logo" src="/img/edinburgh_logo.png"></a>';
#$html .= '<a href="http://bbsrc.ac.uk"><img title="bbsrc" class="lb-footer-logo" src="/img/bbsrc_logo.jpg"></a>';

$html .= '</div>';

#  return sprintf( qq(
#  <div class="column-two left">
#		   %s release %s - %s -
#		  tardigrades.org &copy; <span class="print_hide"><a href="http://www.ed.ac.uk/" style="white-space:nowrap">Edinburgh University</a> / EnsEMBL &copy; <a href="http://www.ebi.ac.uk/" style="white-space:nowrap">EBI</a> -- Tardigrade logo by <a href="http://www.kumamushisan.net/en/labo.html" style="white-space:nowrap">©TARUDI & Camo Sakamoto</a></span>
#      <span class="screen_hide_inline">tardigrades.org</span> %s
#  </div>),     "tardigrades.org", "1", "November 2016", $html
## ...END CAENSEMBL MODIFICATIONS
	       );

}

1;
