//
// MIT License
//
// Copyright (c) 2025 Sophiestication Software, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Testing
import Foundation
@testable import SwiftyXMLSequence

struct LinebreakTest {
    enum Error: Swift.Error {
        case fileNoSuchFile
    }

    private func makeEvents<Element: ElementRepresentable & Equatable & Sendable>(
        _ elementType: Element.Type = XMLElement.self,
        for filename: String
    ) async throws -> URLSession.AsyncXMLParsingEvents<Element> {
        guard let fileURL = Bundle.module.url(forResource: filename, withExtension: "html") else {
            #expect(Bool(false), "Failed to find \(filename).html file.")
            throw Error.fileNoSuchFile
        }

        let (events, _) = try await URLSession.shared.xml(
            Element.self,
            for: fileURL
        )

        return events
    }

    @Test func testLinebreakMapping() async throws {
        let events = try await makeEvents(HTMLElement.self, for: "whitespace-collapse")

        let whitespaceEvents = try await events
            .map(whitespace: { element, _ in
                element.whitespacePolicy
            })
            .map(linebreaks: { _, _ in
                "\n"
            })

        let formatter = ParsingEventDebugFormatter()
        let debugDescription = try await formatter.format(whitespaceEvents)

        let expectedText = "[block [remove:↩︎····] [block [remove:↩︎········] [block block] [remove:↩︎····] block] [remove:↩︎····] [block [remove:↩︎↩︎↩︎········] [block [remove:·] [Art] [collapse:····] [Deco] [remove:····] [↩︎] block] [inline [Art Deco got its name after the] [remove:····] [↩︎] [block [remove:··] [1925] [remove:···] [↩︎] block] [remove:···] [Exposition] [collapse:·] [inline [remove:·] [internationale] [collapse:······] inline] [remove:·] [des arts décoratifs et industriels modernes] [collapse:↩︎↩︎↩︎········] [(International Exhibition of Modern Decorative and Industrial Arts) held in Paris. Art Deco has its origins in bold geometric forms of the Vienna Secession and Cubism.] [collapse:↩︎↩︎···········] inline] [remove:↩︎↩︎········] [inline [remove:↩︎········] [From its outset, it was influenced] [collapse:····] [by the bright colors of Fauvism and of the Ballets] [collapse:······] [Russes, and the exoticized styles of art from] [collapse:↩︎↩︎·············] [China, Japan, India, Persia, ancient Egypt, and Maya.] inline] [remove:↩︎↩︎↩︎····] block] [remove:↩︎] block]"

        #expect(debugDescription == expectedText)
    }

    @Test func testMarkupDocument() async throws {
        let text = try await makeEvents(HTMLElement.self, for: "sample1")
            .collect { element, attributes in
                return switch element {
                case .title, .section:
                    true
                default:
                    false
                }
            }
            .filter { element, _ in
                return switch element {
                case .figure, .style:
                    false
                default:
                    true
                }
            }
            .filter { element, attributes in
                if attributes.contains(class: "noprint") { return false }
                if attributes.contains(class: "mw-ref") { return false }
                if attributes.contains(class: "reflist") { return false }
                if attributes.contains(class: "navigation-not-searchable") { return false }

                if attributes.contains(id: ["mw6Q", "mw7A", "mwAUU", "mwAWI"]) {
                    return false
                }

                return true
            }
            .map(whitespace: { element, _ in
                element.whitespacePolicy
            })
            .map(linebreaks: { element, _ in
                return switch element {
                case .title, .h1, .h2, .h3, .h4, .h5, .h6, .p, .ul, .ol, .li:
                    "\n \n"
                default:
                    "\n"
                }
            })
            .collapse()
            .flatMap { event in
                switch event {
                case .begin(let element, _):
                    switch element {
                    case .li:
                        return [.text("- ") , event].async
                    default:
                        break
                    }
                default:
                    break
                }

                return [event].async
            }
            .reduce(into: String()) { partialResult, event in
                switch event {
                case .text(let string):
                    partialResult.append(string)
                    break
                default:
                    break
                }
            }

        let expectedText = """
            Der Blaue Reiter
             
            Der Blaue Reiter (The Blue Rider) was a group of artists and a designation by Wassily Kandinsky and Franz Marc for their exhibition and publication activities, in which both artists acted as sole editors in the almanac of the same name (first published in mid-May 1912). The editorial team organized two exhibitions in Munich in 1911 and 1912 to demonstrate their art-theoretical ideas based on the works of art exhibited. Traveling exhibitions in German and other European cities followed. The Blue Rider disbanded at the start of World War I in 1914.
             
            The artists associated with Der Blaue Reiter were important pioneers of modern art of the 20th century; they formed a loose network of relationships, but not an art group in the narrower sense like Die Brücke (The Bridge) in Dresden. The work of the affiliated artists is assigned to German Expressionism.
             
            History
             
            The forerunner of The Blue Rider was the Neue Künstlervereinigung München (N.K.V.M: New Artists' Association Munich), instigated by Marianne von Werefkin, Alexej von Jawlensky, Adolf Erbslöh and German entrepreneur, art collector, aviation pioneer and musician Oscar Wittenstein. The N.K.V.M was co-founded in 1909 and Kandinsky (as its first chairman) organized the exhibitions of 1909 and 1910. Even before the first exhibition, Kandinsky introduced the so-called "four square meter clause" into the statutes of the N.K.V.M due to a difference of opinion with the painter Charles Johann Palmié; this clause would give Kandinsky the lever to leave the N.K.V.M in 1911.
             
            There were repeated disputes among the conservative forces in the N.K.V.M, which flared up due to Kandinsky's increasingly abstract painting. In December 1911, Kandinsky submitted Composition V for the association's third exhibition, but the jury rejected the painting. In response, Kandinsky, along with Münter, Marc, and others, formed a rival group and quickly organised a parallel exhibition at the same venue, the Thannhauser Gallery, in rooms adjacent to the official show. This breakaway group adopted the name Der Blaue Reiter.
             
            Years later, Kandinsky recalled anticipating the controversy and having already prepared extensive material for the new group's exhibition: "Our halls were close to the rooms of the NKVM exhibition. It was a sensation. Since I anticipated the 'noise' in good time, I had prepared a wealth of exhibition material for the BR [Blaue Reiter]. So the two exhibitions took place simultaneously. (…) Revenge was sweet!". The exhibition was officially titled the First Exhibition of the Editorial Board of Der Blaue Reiter, reflecting Kandinsky and Marc's plans to publish an art almanac under the same name.
             
            Kandinsky resigned as chairmanship of the N.K.V.M. on 10 January 1911 but remained in the association as a simple member. His successor was Adolf Erbslöh. In June, Kandinsky developed plans for his activities outside of the N.K.V.M. He intended to publish a "kind of almanac" which could be called Die Kette (The Chain). On 19 June, he pitched his idea to Marc and won him over by offering him the co-editing of the book.
             
            The name of the movement is the title of a painting that Kandinsky created in 1903, but it is unclear whether it is the origin of the name of the movement as Professor Klaus Lankheit learned that the title of the painting had been overwritten. Kandinsky wrote 20 years later that the name is derived from Marc's enthusiasm for horses and Kandinsky's love of riders, combined with a shared love of the color blue. For Kandinsky, blue was the color of spirituality; the darker the blue, the more it awakened human desire for the eternal (as he wrote in his 1911 book On the Spiritual in Art).
             
            Within the group, artistic approaches and aims varied from artist to artist; however, the artists shared a common desire to express spiritual truths through their art. They believed in the promotion of modern art; the connection between visual art and music; the spiritual and symbolic associations of color; and a spontaneous, intuitive approach to painting. Members were interested in European medieval art and primitivism, as well as the contemporary, non-figurative art scene in France. As a result of their encounters with Cubist, Fauvist and Rayonist ideas, they moved towards abstraction.
             
            Der Blaue Reiter organized exhibitions in 1911 and 1912 that toured Germany. They also published an almanac featuring contemporary, primitive and folk art, along with children's paintings. In 1913, they exhibited in the first German Herbstsalon.
             
            The group was disrupted by the outbreak of the First World War in 1914. Franz Marc and August Macke were killed in combat. Wassily Kandinsky returned to Russia, and Marianne von Werefkin and Alexej von Jawlensky fled to Switzerland. There were also differences in opinion within the group. As a result, Der Blaue Reiter was short-lived, lasting for only three years from 1911 to 1914.
             
            In 1923, Kandinsky, Feininger, Klee and Alexej von Jawlensky formed the group Die Blaue Vier (The Blue Four) at the instigation of painter and art dealer Galka Scheyer. Scheyer organized Blue Four exhibitions in the United States from 1924 onward.
             
            An extensive collection of paintings by Der Blaue Reiter is exhibited in the Städtische Galerie in the Lenbachhaus in Munich.
             
            Almanac
             
            Conceived in June 1911, Der Blaue Reiter Almanach (The Blue Rider Almanac) was published in early 1912 by Piper in an edition that sold approximately 1100 copies; on 11 May, Franz Marc received the first print. The volume was edited by Kandinsky and Marc; its costs were underwritten by the industrialist and art collector Bernhard Koehler, a relative of Macke. It contained reproductions of more than 140 artworks, and 14 major articles. A second volume was planned, but the start of World War I prevented it. Instead, a second edition of the original was printed in 1914, again by Piper.
             
            The contents of the Almanac included:
             
            - Marc's essay "Spiritual Treasures," illustrated with children's drawings, German woodcuts, Chinese paintings, and Pablo Picasso's Woman with Mandolin at the Piano
             
            - an article by French critic Roger Allard on Cubism
             
            - Arnold Schoenberg's article "The Relationship to the Text", and a facsimile of his song "Herzgewächse"
             
            - facsimiles of song settings by Alban Berg and Anton Webern
             
            - Thomas de Hartmann's essay "Anarchy in Music"
             
            - an article by Leonid Sabaneyev about Alexander Scriabin
             
            - an article by Erwin von Busse on Robert Delaunay, illustrated with a print of his The Window on the City
             
            - an article by Vladimir Burliuk on contemporary Russian art
             
            - Macke's essay "Masks"
             
            - Kandinsky's essay "On the Question of Form"
             
            - Kandinsky's "On Stage Composition"
             
            - Kandinsky's The Yellow Sound.
             
            The art reproduced in the Almanac marked a dramatic turn away from a Eurocentric and conventional orientation. The selection was dominated by primitive, folk and children's art, with pieces from the South Pacific and Africa, Japanese drawings, medieval German woodcuts and sculpture, Egyptian puppets, Russian folk art, and Bavarian religious art painted on glass. The five works by Van Gogh, Cézanne, and Gauguin were outnumbered by seven from Henri Rousseau and thirteen from child artists.
             
            Exhibitions
             
            First exhibition
             
            On December 18, 1911, the First exhibition of the editorial board of Der Blaue Reiter (Erste Ausstellung der Redaktion Der Blaue Reiter) opened at the Heinrich Thannhauser's Moderne Galerie in Munich, running through the first days of 1912. 43 works by 14 artists were shown: paintings by Henri Rousseau, Albert Bloch, David Burliuk, Wladimir Burliuk, Heinrich Campendonk, Robert Delaunay, Elisabeth Epstein, Eugen von Kahler, Wassily Kandinsky, August Macke, Franz Marc, Gabriele Münter, Jean Bloé Niestlé and Arnold Schoenberg, and an illustrated catalogue edited.
             
            From January 1912 through July 1914, the exhibition toured Europe with venues in Cologne, Berlin, Bremen, Hagen, Frankfurt, Hamburg, Budapest, Oslo, Helsinki, Trondheim and Göteborg.
             
            Second exhibition
             
            From February 12 through April 2, 1912, the Second exhibition of the editorial board of Der Blaue Reiter (Zweite Ausstellung der Redaktion Der Blaue Reiter) showed works in black-and-white at the New Art Gallery of Hans Goltz (Neue Kunst Hans Goltz) in Munich.
             
            Other shows
             
            The artists of Der Blaue Reiter also participated in these other exhibitions:
             
            - 1912 Sonderbund westdeutscher Kunstfreunde und Künstler exhibition, held in Cologne
             
            - Erster Deutscher Herbstsalon (organised by Herwarth Walden and his gallery, Der Sturm), held in 1913 in Berlin
            """

        #expect(text == expectedText)
    }
}
