# Hallmarks-of-cancer-interactive-simulation
This modeol runs in Netlogo 6.4.
A detailed description is included in the netlogo simulation file info tab.

This model is an educational simulation of tumor growth and chemotherapy. It introduces several simplified characteristics of cancer cells, including sustained cell proliferation, evasion of growth suppression, replicative immortality, and reduced dependence on cellular anchorage, based on the theoretical foundations of the “Hallmarks of Cancer” (Douglas Hanahan, “Hallmarks of Cancer: New Dimensions,” Cancer Discovery, January 1, 2022; 12(1): 31–46. https://doi.org/10.1158/2159-8290.CD-21-1059).

I have used it as an innovative teaching approach, for basic and intermediate-level students.
The activity was divided into two parts:

The first consisted of an brief explanation of the morphological and behavioral differences between healthy cells and cancer cells (slides are included in the repository).

In the second, hands-on part, the students can set the features of the cancer cells and see how they affect the tumor behavior. They can also choose to administer chemotherapy, which slows tumor growth by killing the cells, can also degrade the patient's condition due to toxicity.

The purpose of the activity was to explain the fundamentals of tumor growth to young people in a simple and accessible way, while illustrating the delicate balance between stopping tumor growth and preserving the health of oncological patients. It also sought to raise awareness among children and adolescents about the challenges that cancer presents to scientists, physicians, and family members of oncological patients.

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
