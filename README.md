# Hallmarks-of-cancer-interactive-simulation
This model is an educational simulation of tumor growth and chemotherapy. It introduces several simplified characteristics associated with cancer, including sustained cell proliferation, evasion of growth suppression, replicative immortality, and reduced dependence on cellular anchorage. 

This modeol runs in Netlogo 6.4.
A detailed description is included in the netlogo simulation file info tab.

Using an innovative teaching approach, I designed an educational experience for intermediate-level students that included a videogame-style simulation of cancer behavior based on the theoretical foundations of the “Hallmarks of Cancer” (Douglas Hanahan, “Hallmarks of Cancer: New Dimensions,” Cancer Discovery, January 1, 2022; 12(1): 31–46. https://doi.org/10.1158/2159-8290.CD-21-1059).

The activity is divided into two parts.

The first consisted of an explanation of the morphological and behavioral differences between healthy cells and cancer cells.

For the second part, I programmed a tumor-growth simulation using the NetLogo platform. In the simulation, cells grow according to how the students configure the tumor’s characteristics. Students can also choose to administer chemotherapy, which slows tumor growth. However, the patient with the tumor is displayed on one side of the simulation, and the patient’s health worsens both as the tumor grows and as higher doses of chemotherapy are administered.

The purpose of the activity was to explain the fundamentals of tumor growth to young people in a simple and accessible way, while illustrating the delicate balance between stopping tumor growth and preserving the health of oncology patients. It also sought to raise awareness among children and adolescents about the challenges that cancer presents to us as scientists, treating physicians, and family members of oncology patients.

## Attribution and license

This code adapts portions of:

Wilensky, U. (2007). *NetLogo Hex Cell Aggregation model*.
Center for Connected Learning and Computer-Based Modeling,
Northwestern University, Evanston, Illinois.

Original model:
http://ccl.northwestern.edu/netlogo/models/HexCellAggregation

The original model and this modified version are distributed under the
Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.

I substantially modified the model by adding tumor-specific growth rules, replicative lifespan, anchorage dependence, chemotherapy and toxicity, patient-condition calculations, and a patient HUD.
